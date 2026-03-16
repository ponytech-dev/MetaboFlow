export function Footer() {
  return (
    <footer className="border-t border-border/40 py-4">
      <div className="mx-auto flex max-w-screen-xl items-center justify-between px-6">
        <p className="text-xs text-muted-foreground">
          MetaboFlow — Open-source metabolomics analysis platform
        </p>
        <p className="text-xs text-muted-foreground">
          Powered by XCMS · MZmine · HMDB · KEGG
        </p>
      </div>
    </footer>
  );
}
