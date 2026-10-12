# Oracle cases for the Vite integration (P0: manifest + tag helpers).
#
# Run against the ORIGINAL gems (vite_rails 3.0.19 / vite_ruby 3.9.2,
# the versions qp2/website pins in its Gemfile.lock):
#   ruby oracle/vite_cases.rb > oracle/vite_expected.yml
#
# Each line: "<case_id>\t<value>". Mirrored 1:1 in
# action_view.cr/spec/vite_spec.cr. The manifest fixture mirrors a real
# `vite build` output (vite 5/6 format: hashed files, `imports`,
# `css`, `isEntry`).

gem "vite_rails", "= 3.0.19"
gem "actionpack", "= 8.1.4"
gem "actionview", "= 8.1.4"
require "vite_rails"
require "action_view"

def render(v)
  case v
  when String then v.gsub("\n", "\\n")
  else v.inspect
  end
end

def case_run(id)
  puts "#{id}\t#{render(yield)}"
rescue StandardError => e
  puts "#{id}\traise:#{e.class.name}"
end

require "fileutils"
ROOT = File.expand_path("vite_fixture", __dir__)
FileUtils.rm_rf(ROOT)
FileUtils.mkdir_p(File.join(ROOT, "public/vite/.vite"))
FileUtils.mkdir_p(File.join(ROOT, "app/frontend"))
FileUtils.mkdir_p(File.join(ROOT, "config"))

File.write(File.join(ROOT, "config/vite.json"), <<~JSON)
  {
    "all": { "sourceCodeDir": "app/frontend" },
    "test": { "autoBuild": false, "publicOutputDir": "vite" }
  }
JSON

# Mirrors a real `vite build` manifest (vite 5/6 format).
File.write(File.join(ROOT, "public/vite/.vite/manifest.json"), <<~JSON)
  {
    "_vendor-abc123.js": { "file": "assets/vendor-abc123.js", "name": "vendor-abc123" },
    "entrypoints/application.js": {
      "file": "assets/application-def456.js",
      "name": "application",
      "src": "entrypoints/application.js",
      "isEntry": true,
      "imports": ["_vendor-abc123.js"],
      "css": ["assets/application-def456.css"]
    },
    "entrypoints/print.css": {
      "file": "assets/print-1b2c3d.css",
      "name": "print",
      "src": "entrypoints/print.css",
      "isEntry": true
    },
    "styles/admin.css": {
      "file": "assets/admin-0af1b2.css",
      "name": "admin",
      "src": "styles/admin.css"
    },
    "entrypoints/second.js": {
      "file": "assets/second-987654.js",
      "name": "second",
      "src": "entrypoints/second.js",
      "isEntry": true
    },
    "images/logo-789.png": { "file": "assets/logo-789.png", "name": "logo-789", "src": "images/logo-789.png" },
    "src/nested.js": { "file": "assets/nested-0f1e2d.js", "name": "nested", "src": "src/nested.js" }
  }
JSON

ENV["RAILS_ENV"] = "test"
ViteRuby.configure(root: ROOT)

class ViteOracleView < ActionView::Base
  include ViteRails::TagHelpers
end

VIEW = ViteOracleView.new(nil, [], nil)

# --- path resolution ------------------------------------------------------

case_run("path_js_entry") { VIEW.vite_asset_path("application", type: :javascript) }
case_run("path_css_nested") { VIEW.vite_asset_path("styles/admin.css") }
case_run("path_source_dir") { VIEW.vite_asset_path("~/src/nested.js") }
case_run("path_image") { VIEW.vite_asset_path("images/logo-789.png") }
case_run("path_without_type_missing") { VIEW.vite_asset_path("application") }
case_run("path_missing_entry") { VIEW.vite_asset_path("nope.js") }

# --- tags -----------------------------------------------------------------

case_run("js_tag") { VIEW.vite_javascript_tag("application") }
case_run("js_tag_no_preload_no_styles") do
  VIEW.vite_javascript_tag("application", skip_preload_tags: true, skip_style_tags: true)
end
case_run("js_tag_two_entries") do
  VIEW.vite_javascript_tag("application", "second")
end
case_run("css_tag") { VIEW.vite_stylesheet_tag("print") }
case_run("css_tag_nested") { VIEW.vite_stylesheet_tag("styles/admin.css") }
case_run("image_tag") { VIEW.vite_image_tag("images/logo-789.png") }
case_run("client_tag_dev_off") { VIEW.vite_client_tag.to_s }
case_run("react_refresh_dev_off") { VIEW.vite_react_refresh_tag.to_s }
case_run("js_tag_missing") { VIEW.vite_javascript_tag("nope") }
