#:sdk Aspire.AppHost.Sdk@13.0.0
using System.Diagnostics;
using System.Text.Json;

using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

var builder = DistributedApplication.CreateBuilder(args);

builder
    .AddVSCodePrivateMarketplace("vscode-private-marketplace")
    .WithMarketplaceConfiguration(
        organizationName: "Contoso",
        contactSupportUri: "mailto:privatemktplace@microsoft.com",
        upstreamingMode: MarketplaceUpstreamingMode.SearchAndAssets)
    .WithOpenGroupPolicyEditorCommand()
    .WithOpenVSCodeCommand();

builder.Build().Run();

public enum MarketplaceUpstreamingMode
{
    None,
    Search,
    SearchAndAssets
}

public static class MarketplaceExtensions
{
    public static IResourceBuilder<ContainerResource> AddVSCodePrivateMarketplace(
        this IDistributedApplicationBuilder builder,
        string name = "vscode-private-marketplace",
        string containerImage = "mcr.microsoft.com/vsmarketplace/vscode-private-marketplace")
    {
        var marketplacePort = builder.Configuration.GetValue<int?>("Marketplace:Port") ?? 0;
        
        var marketplace = builder.AddContainer(name, containerImage)
            .WithEnvironment("ASPNETCORE_URLS", "https://+:443")
            .WithHttpsEndpoint(
                port: marketplacePort == 0 ? null : marketplacePort,
                name: name,
                targetPort: 443)
            .WithUrlForEndpoint(name, annotation => annotation.DisplayText = "Home")
            .WithUrl($"https://github.com/microsoft/vsmarketplace/blob/main/privatemarketplace/quickstart/aspire/README.md", "README")
            .WithBindMount(Path.Combine(Directory.GetCurrentDirectory(), "data", "extensions"), "/extensions")
            .WithBindMount(Path.Combine(Directory.GetCurrentDirectory(), "data", "logs"), "/logs")
            .WithOtlpExporter()
            .RunWithHttpsDevCertificate();

        // Save allocated port to appsettings.json for future runs
        if (marketplacePort == 0)
        {
            var appsettingsPath = Path.Combine(Directory.GetCurrentDirectory(), "appsettings.json");
            builder.Eventing.Subscribe<ResourceEndpointsAllocatedEvent>(marketplace.Resource, (e, ct) =>
            {
                var endpoint = e.Resource.Annotations.OfType<EndpointAnnotation>()
                    .FirstOrDefault(a => a.Name == name);
                
                if (endpoint?.Port.HasValue)
                {
                    var config = new { Marketplace = new { Port = endpoint.Port.Value } };
                    var json = JsonSerializer.Serialize(config, new JsonSerializerOptions { WriteIndented = true });
                    File.WriteAllText(appsettingsPath, json);
                }
                return Task.CompletedTask;
            });
        }

        return marketplace;
    }

    public static IResourceBuilder<ContainerResource> WithMarketplaceConfiguration(
        this IResourceBuilder<ContainerResource> builder,
        string organizationName,
        string contactSupportUri,
        MarketplaceUpstreamingMode upstreamingMode)
    {
        return builder
            .WithEnvironment(context =>
            {
                context.EnvironmentVariables["Marketplace__BaseUrl"] = builder.Resource.GetEndpoint("vscode-private-marketplace").Url.ToString();
            })
            .WithEnvironment("Marketplace__OrganizationName", organizationName)
            .WithEnvironment("Marketplace__ContactSupportUri", contactSupportUri)
            .WithEnvironment("Marketplace__LogsDirectory", "/logs")
            .WithEnvironment("Marketplace__ExtensionSourceDirectory", "/extensions")
            .WithEnvironment("Marketplace__Upstreaming__Mode", upstreamingMode.ToString());
    }

    public static IResourceBuilder<ContainerResource> WithOpenVSCodeCommand(
        this IResourceBuilder<ContainerResource> builder)
    {
        var resource = builder.Resource;
        
        return builder.WithCommand(
            name: "open",
            displayName: "Open VS Code",
            executeCommand: context =>
            {
                try
                {
                    var endpoint = resource.Annotations.OfType<EndpointAnnotation>()
                        .FirstOrDefault(e => e.Name == "vscode-private-marketplace");

                    if (endpoint?.AllocatedEndpoint == null)
                    {
                        return Task.FromResult(new ExecuteCommandResult
                        {
                            Success = false,
                            ErrorMessage = "Marketplace endpoint not allocated."
                        });
                    }

                    var marketplaceUrl = endpoint.AllocatedEndpoint.UriString;

                    // Find private VS Code install in .vscode folder
                    var vscodePath = Path.Combine(Directory.GetCurrentDirectory(), ".vscode", "Code.exe");

                    if (!File.Exists(vscodePath))
                    {
                        return Task.FromResult(new ExecuteCommandResult
                        {
                            Success = false,
                            ErrorMessage = "Private VS Code installation not found in .vscode folder."
                        });
                    }

                    // Create isolated user data and extensions directories
                    var userDataDir = Path.Combine(Directory.GetCurrentDirectory(), ".vscode-data");
                    var extensionsDir = Path.Combine(Directory.GetCurrentDirectory(), ".vscode-extensions");
                    Directory.CreateDirectory(userDataDir);
                    Directory.CreateDirectory(extensionsDir);

                    Process.Start(new ProcessStartInfo
                    {
                        FileName = vscodePath,
                        Arguments = $"--user-data-dir \"{userDataDir}\" --extensions-dir \"{extensionsDir}\" --extensionGalleryServiceUrl {marketplaceUrl}",
                        UseShellExecute = true
                    });

                    return Task.FromResult(new ExecuteCommandResult { Success = true });
                }
                catch (Exception ex)
                {
                    return Task.FromResult(new ExecuteCommandResult
                    {
                        Success = false,
                        ErrorMessage = $"Failed to launch VS Code: {ex.Message}"
                    });
                }
            },
            commandOptions: new CommandOptions
            {
                UpdateState = context =>
                {
                    var snapshot = context.ResourceSnapshot;
                    
                    if (snapshot.State?.Text != "Running")
                    {
                        return ResourceCommandState.Hidden;
                    }

                    var healthCheckProperties = snapshot.Properties
                        .Where(p => p.Name.Contains("health", StringComparison.OrdinalIgnoreCase))
                        .ToList();

                    if (healthCheckProperties.Any())
                    {
                        var allHealthy = healthCheckProperties.All(hc =>
                            hc.Value.ToString().Contains("Healthy", StringComparison.OrdinalIgnoreCase) ||
                            hc.Value.ToString().Contains("Success", StringComparison.OrdinalIgnoreCase));

                        return allHealthy ? ResourceCommandState.Enabled : ResourceCommandState.Disabled;
                    }

                    var statusProperties = snapshot.Properties
                        .Where(p => p.Name.Contains("Status", StringComparison.OrdinalIgnoreCase))
                        .ToList();

                    if (statusProperties.Any())
                    {
                        var hasGoodStatus = statusProperties.Any(sp =>
                            sp.Value.ToString().Contains("Healthy", StringComparison.OrdinalIgnoreCase) ||
                            sp.Value.ToString().Contains("Running", StringComparison.OrdinalIgnoreCase) ||
                            sp.Value.ToString().Contains("Ready", StringComparison.OrdinalIgnoreCase));

                        return hasGoodStatus ? ResourceCommandState.Enabled : ResourceCommandState.Disabled;
                    }

                    return ResourceCommandState.Enabled;
                },
                Description = "Launch Visual Studio Code connected to this private marketplace.",
                IconName = "Code",
                IconVariant = IconVariant.Filled,
                IsHighlighted = true
            });
    }

    public static IResourceBuilder<ContainerResource> WithOpenGroupPolicyEditorCommand(
        this IResourceBuilder<ContainerResource> builder)
    {
        return builder.WithCommand(
            name: "gpedit",
            displayName: "Open Group Policy Editor",
            executeCommand: context =>
            {
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "gpedit.msc",
                        UseShellExecute = true
                    });

                    return Task.FromResult(new ExecuteCommandResult { Success = true });
                }
                catch (Exception ex)
                {
                    return Task.FromResult(new ExecuteCommandResult
                    {
                        Success = false,
                        ErrorMessage = $"Failed to launch Group Policy Editor: {ex.Message}"
                    });
                }
            },
            commandOptions: new CommandOptions
            {
                UpdateState = context =>
                {
                    var snapshot = context.ResourceSnapshot;
                    
                    if (snapshot.State?.Text != "Running")
                    {
                        return ResourceCommandState.Hidden;
                    }

                    // Check if VSCode.admx exists in PolicyDefinitions folder
                    var policyDefinitionsPath = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                        "PolicyDefinitions",
                        "VSCode.admx");

                    return File.Exists(policyDefinitionsPath) ? ResourceCommandState.Enabled : ResourceCommandState.Hidden;
                },
                Description = "Launch the Local Group Policy Editor to configure VS Code policies.",
                IconName = "Settings",
                IconVariant = IconVariant.Filled,
                IsHighlighted = false
            });
    }
}

/// <summary>
/// Extensions for adding Dev Certs to aspire resources.
/// </summary>
public static class DevCertHostingExtensions
{
    /// <summary>
    /// Injects the ASP.NET Core HTTPS developer certificate into the resource via the specified environment variables when
    /// <paramref name="builder"/>.<see cref="IResourceBuilder{T}.ApplicationBuilder">ApplicationBuilder</see>.<see cref="IDistributedApplicationBuilder.ExecutionContext">ExecutionContext</see>.<see cref="DistributedApplicationExecutionContext.IsRunMode">IsRunMode</see><c> == true</c>.<br/>
    /// If the resource is a <see cref="ContainerResource"/>, the certificate files will be bind mounted into the container.
    /// </summary>
    /// <remarks>
    /// This method <strong>does not</strong> configure an HTTPS endpoint on the resource.
    /// Use <see cref="ResourceBuilderExtensions.WithHttpsEndpoint{TResource}"/> to configure an HTTPS endpoint.
    /// </remarks>
    public static IResourceBuilder<TResource> RunWithHttpsDevCertificate<TResource>(
        this IResourceBuilder<TResource> builder, string certFileEnv = "ASPNETCORE_Kestrel__Certificates__Default__Path")
        where TResource : IResourceWithEnvironment
    {
        builder.ApplicationBuilder.Eventing.Subscribe<BeforeStartEvent>(async (e, ct) =>
        {
            var logger = e.Services.GetRequiredService<ResourceLoggerService>().GetLogger(builder.Resource);
            if (logger is null)
            {
                throw new InvalidOperationException("Failed to get logger for resource.");
            }
            // Export the ASP.NET Core HTTPS development certificate to a file and configure the resource to use it via
            // the specified environment variables.
            var (exported, certPath) = await TryExportDevCertificateAsync(builder.ApplicationBuilder, logger);

            if (!exported)
            {
                // The export failed for some reason, don't configure the resource to use the certificate.
            }

            if (builder.Resource is ContainerResource containerResource)
            {
                // Bind-mount the certificate files into the container.
                const string DEV_CERT_BIND_MOUNT_DEST_DIR = "/dev-certs";

                var certFileName = Path.GetFileName(certPath);

                var bindSource = Path.GetDirectoryName(certPath) ?? throw new UnreachableException();

                var certFileDest = $"{DEV_CERT_BIND_MOUNT_DEST_DIR}/{certFileName}";

                builder.ApplicationBuilder.CreateResourceBuilder(containerResource)
                    .WithBindMount(bindSource, DEV_CERT_BIND_MOUNT_DEST_DIR, isReadOnly: true)
                    .WithEnvironment(certFileEnv, certFileDest);
            }
        });

        return builder;
    }

    public static async Task<(bool, string CertFilePath)> TryExportDevCertificateAsync(IDistributedApplicationBuilder builder)
    {
        return await TryExportDevCertificateAsync(builder, null);
    }

    private static async Task<(bool, string CertFilePath)> TryExportDevCertificateAsync(IDistributedApplicationBuilder builder, ILogger? logger)
    {
        // Exports the ASP.NET Core HTTPS development certificate & private key to PEM files using 'dotnet dev-certs https' to a temporary
        // directory and returns the path.
        // TODO: Check if we're running on a platform that already has the cert and key exported to a file (e.g. macOS) and just use those instead.
        var appNameHash = builder.Configuration["AppHost:Sha256"]![..10];
        var tempDir = Path.Combine(Path.GetTempPath(), $"aspire.{appNameHash}");
        var certExportPath = Path.Combine(tempDir, "dev-cert.pfx");

        if (File.Exists(certExportPath))
        {
            // Certificate already exported, return the path.
            return (true, certExportPath);
        }

        if (File.Exists(certExportPath))
        {
            File.Delete(certExportPath);
        }

        if (!Directory.Exists(tempDir))
        {
            Directory.CreateDirectory(tempDir);
        }

        string[] args = ["dev-certs", "https", "--export-path", $"\"{certExportPath}\"", "--format", "pfx", "--password", "\"\""];
        var argsString = string.Join(' ', args);

        logger?.LogTrace("Running command to export dev cert: {ExportCmd}", $"dotnet {argsString}");
        var exportStartInfo = new ProcessStartInfo
        {
            FileName = "dotnet",
            Arguments = argsString,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden,
        };

        using var exportProcess = new Process { StartInfo = exportStartInfo };

        Task? stdOutTask = null;
        Task? stdErrTask = null;

        try
        {
            try
            {
                if (exportProcess.Start())
                {
                    stdOutTask = ConsumeOutput(exportProcess.StandardOutput, msg => logger?.LogInformation("> {StandardOutput}", msg));
                    stdErrTask = ConsumeOutput(exportProcess.StandardError, msg => logger?.LogError("! {ErrorOutput}", msg));
                }
            }
            catch (Exception ex)
            {
                logger?.LogError(ex, "Failed to start HTTPS dev certificate export process");
                throw;
            }

            var timeout = TimeSpan.FromSeconds(5);
            var exited = exportProcess.WaitForExit(timeout);

            if (exited && File.Exists(certExportPath))
            {
                return (true, certExportPath);
            }

            if (exportProcess.HasExited && exportProcess.ExitCode != 0)
            {
                logger?.LogError("HTTPS dev certificate export failed with exit code {ExitCode}", exportProcess.ExitCode);
            }
            else if (!exportProcess.HasExited)
            {
                exportProcess.Kill(true);
                logger?.LogError("HTTPS dev certificate export timed out after {TimeoutSeconds} seconds", timeout.TotalSeconds);
            }
            else
            {
                logger?.LogError("HTTPS dev certificate export failed for an unknown reason");
            }
            return default;
        }
        finally
        {
            await Task.WhenAll(stdOutTask ?? Task.CompletedTask, stdErrTask ?? Task.CompletedTask);
        }

        static async Task ConsumeOutput(TextReader reader, Action<string> callback)
        {
            char[] buffer = new char[256];
            int charsRead;

            while ((charsRead = await reader.ReadAsync(buffer, 0, buffer.Length)) > 0)
            {
                callback(new string(buffer, 0, charsRead));
            }
        }
    }
}

