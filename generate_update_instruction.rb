require 'json'

# URL found via NotionAPI.search
MARKET_MAP_URL = "https://notion.so/1b67bd4299e781a6882ddb860fbc39bb"
RESEARCH_FILE = "synthetic_data_research.md"

if File.exist?(RESEARCH_FILE)
  content = File.read(RESEARCH_FILE)
  
  # Construct the XML instruction
  puts "📋 Copy and paste this block into Claude Code to update the market map:"
  puts ""
  puts "<invoke name=\"mcp__theorymcp__update_market_map_content\">
"
  puts "  <parameter name=\"market_map_notion_link\">#{MARKET_MAP_URL}</parameter>"
  puts "  <parameter name=\"content_to_append\">"
  puts content.gsub('<', '&lt;').gsub('>', '&gt;') # Basic escaping for XML
  puts "  </parameter>"
  puts "</invoke>"
else
  puts "Error: #{RESEARCH_FILE} not found."
end