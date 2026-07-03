// Test stub for the @theme-original/Mermaid webpack alias that Docusaurus
// resolves at build time. Renders the diagram source as plain text.
export default function MermaidOriginal({value, ...rest}) {
  return (
    <div data-testid="mermaid-diagram" {...rest}>
      {value}
    </div>
  );
}
