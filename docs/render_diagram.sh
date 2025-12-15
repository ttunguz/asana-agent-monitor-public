#!/bin/bash
# Render Mermaid diagrams to PNG using mermaid-cli (mmdc)

# Check if mmdc is installed
if ! command -v mmdc &> /dev/null; then
    echo "mermaid-cli not found. Installing..."
    npm install -g @mermaid-js/mermaid-cli
fi

# Render main workflow diagram
mmdc -i docs/workflow.mmd -o docs/workflow.png -w 1200 -H 800 -b white

# Render architecture diagram
mmdc -i docs/architecture.mmd -o docs/architecture.png -w 1400 -H 1000 -b white

echo "✅ Diagrams rendered successfully!"
echo "   - docs/workflow.png"
echo "   - docs/architecture.png"
