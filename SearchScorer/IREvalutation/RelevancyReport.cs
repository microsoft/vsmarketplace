namespace SearchScorer.IREvalutation
{
    public class RelevancyReport
    {
        public RelevancyReport(VariantReport controlReport, VariantReport treatmentReport)
        {
            ControlReport = controlReport;
            TreatmentReport = treatmentReport;
        }

        public VariantReport ControlReport { get; }
        public VariantReport TreatmentReport { get; }
    }
}
