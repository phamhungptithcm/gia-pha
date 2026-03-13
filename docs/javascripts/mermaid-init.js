document$.subscribe(() => {
  if (!window.mermaid) {
    return;
  }

  window.mermaid.initialize({
    startOnLoad: false,
    securityLevel: "loose",
    theme: "default",
  });

  const diagrams = document.querySelectorAll(".mermaid");
  if (diagrams.length > 0) {
    window.mermaid.run({
      nodes: diagrams,
    });
  }
});
