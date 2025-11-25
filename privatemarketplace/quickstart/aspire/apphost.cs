#:sdk Aspire.AppHost.Sdk@13.0.0
using System.Diagnostics;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

var builder = DistributedApplication.CreateBuilder(args);

var marketplace = builder.AddContainer("vscode-private-marketplace", "mcr.microsoft.com/vsmarketplace/vscode-private-marketplace")
    .WithEnvironment("ASPNETCORE_URLS", "https://+:443")
    .WithHttpsEndpoint(name:"vscode-private-marketplace", targetPort: 443)
    .WithUrlForEndpoint("vscode-private-marketplace", (annotation) => annotation.DisplayText = "Home")
    .WithBindMount(Path.Combine(Directory.GetCurrentDirectory(), "data", "extensions"), "/extensions")
    .WithBindMount(Path.Combine(Directory.GetCurrentDirectory(), "data", "logs"), "/logs")
    .WithOtlpExporter()
;

marketplace.RunWithHttpsDevCertificate();

marketplace    
    .WithEnvironment("Marketplace__BaseUrl", marketplace.GetEndpoint("vscode-private-marketplace"))
    .WithEnvironment("Marketplace__OrganizationName", "Contoso")
    .WithEnvironment("Marketplace__ContactSupportUri", "mailto:privatemktplace@microsoft.com")
    .WithEnvironment("Marketplace__LogsDirectory", "/logs")
    .WithEnvironment("Marketplace__ExtensionSourceDirectory", "/extensions")
    .WithEnvironment("Marketplace__Upstreaming__Mode", nameof(MarketplaceUpstreamingMode.SearchAndAssets))
;

marketplace.WithCommand(
        name: "open",
        displayName: "Open VS Code", 
        executeCommand: async (context) =>
        {
            
            return new ExecuteCommandResult
            {
                Success = false,
                ErrorMessage = "Not implemented yet."
            };
        }, 
        commandOptions: new CommandOptions { 
            UpdateState = (context) => {
                var snapshot = context.ResourceSnapshot;
                var state = snapshot.State;

                // First check if container is running
                if (state?.Text != "Running")
                {
                    return ResourceCommandState.Hidden;
                }

                // Check for health check status in the resource properties
                // Look for health check related properties that indicate the container is healthy
                var healthCheckProperties = snapshot.Properties
                    .Where(p => p.Name.Contains("health", StringComparison.OrdinalIgnoreCase) ||
                                p.Name.Contains("Health", StringComparison.OrdinalIgnoreCase))
                    .ToList();

                // If health checks are present, ensure they're passing
                if (healthCheckProperties.Any())
                {
                    var allHealthy = healthCheckProperties.All(hc =>
                        hc.Value?.ToString()?.Contains("Healthy", StringComparison.OrdinalIgnoreCase) == true ||
                        hc.Value?.ToString()?.Contains("Success", StringComparison.OrdinalIgnoreCase) == true);

                    return allHealthy ? ResourceCommandState.Enabled : ResourceCommandState.Disabled;
                }

                // If no explicit health checks found, check for general container health indicators
                // Look for any "Status" properties that might indicate health
                var statusProperties = snapshot.Properties
                    .Where(p => p.Name.Contains("Status", StringComparison.OrdinalIgnoreCase))
                    .ToList();

                if (statusProperties.Any())
                {
                    var hasGoodStatus = statusProperties.Any(sp =>
                        sp.Value?.ToString()?.Contains("Healthy", StringComparison.OrdinalIgnoreCase) == true ||
                        sp.Value?.ToString()?.Contains("Running", StringComparison.OrdinalIgnoreCase) == true ||
                        sp.Value?.ToString()?.Contains("Ready", StringComparison.OrdinalIgnoreCase) == true);

                    return hasGoodStatus ? ResourceCommandState.Enabled : ResourceCommandState.Disabled;
                }

                // As a final fallback, if container is running, enable the command
                // This ensures the command is available even if health check metadata isn't populated yet
                return ResourceCommandState.Enabled;
            },
            Description = "Launch Visual Studio Code connected to this private marketplace.",
            IconName = "Code",
            IconVariant = IconVariant.Filled,
            IsHighlighted = true
        }
    );

builder.Build().Run();

enum MarketplaceUpstreamingMode
{
    None,
    Search,
    SearchAndAssets
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

        var exportProcess = new Process { StartInfo = exportStartInfo };

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

