# Oracle cases for the Vite dev-server integration (P1: dev tags).
#
# Run against the ORIGINAL gems (vite_rails 3.0.19 / vite_ruby 3.9.2):
#   ruby oracle/vite_dev_cases.rb > oracle/vite_dev_expected.yml
#
# Each line: "<case_id>\t<value>". Mirrored 1:1 in
# action_view.cr/spec/vite_spec.cr (dev describe block).
#
# The dev server is faked with a bare TCP acceptor:
# ViteRuby#dev_server_running? is a real TCP probe against
# config.host:config.port, so accepting connections is all that is
# needed for the gem to switch into dev mode (manifest lookups
# short-circuit to /vite/<name>, vite_client_src / react preamble
# become available). Everything else — tag helpers, path resolution,
# resolve_entries skipping preload/stylesheets in dev — runs the real
# gem code paths.

gem "vite_rails", "= 3.0.19"
gem "actionpack", "= 8.1.4"
gem "actionview", "= 8.1.4"
require "vite_rails"
require "action_view"
require "socket"

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

# --- fake vite dev server: accept + close, nothing more ---------------
fake_server = TCPServer.new("127.0.0.1", 0)
Thread.new { loop { fake_server.accept.close rescue nil } }
FAKE_PORT = fake_server.addr[1]

require "fileutils"
ROOT = File.expand_path("vite_fixture", __dir__)
FileUtils.rm_rf(ROOT)
FileUtils.mkdir_p(File.join(ROOT, "public/vite/.vite"))
FileUtils.mkdir_p(File.join(ROOT, "app/frontend"))
FileUtils.mkdir_p(File.join(ROOT, "config"))

File.write(File.join(ROOT, "config/vite.json"), <<~JSON)
  {
    "all": { "sourceCodeDir": "app/frontend" },
    "development": { "host": "127.0.0.1", "port": #{FAKE_PORT}, "autoBuild": false }
  }
JSON

# Same manifest fixture as vite_cases.rb (not consulted for lookups in
# dev mode, but load_manifest still reads it).
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
    "entrypoints/second.js": {
      "file": "assets/second-987654.js",
      "name": "second",
      "src": "entrypoints/second.js",
      "isEntry": true
    }
  }
JSON

ENV["RAILS_ENV"] = "development"
ViteRuby.configure(root: ROOT)

raise "dev server not detected" unless ViteRuby.instance.dev_server_running?

# In a real app `content_security_policy_nonce` comes from the
# controller (nonce: true in vite_react_refresh_tag); a bare view raises
# NameError. Shim it to nil — exactly what a Rails app without a CSP
# nonce returns — so the tag bytes are captured.
class ViteDevOracleView < ActionView::Base
  include ViteRails::TagHelpers

  def content_security_policy_nonce
    nil
  end
end

VIEW = ViteDevOracleView.new(nil, [], nil)

# --- path resolution (dev: /vite/<entrypoints-name>, no manifest) ------
case_run("dev_path_js_entry") { VIEW.vite_asset_path("application", type: :javascript) }
case_run("dev_path_without_type") { VIEW.vite_asset_path("application") }
case_run("dev_path_source_dir") { VIEW.vite_asset_path("~/src/nested.js") }
case_run("dev_path_image") { VIEW.vite_asset_path("images/logo-789.png") }
case_run("dev_css_path") { VIEW.vite_asset_path("print", type: :stylesheet) }

# --- tags in dev ---------------------------------------------------------
# resolve_entries returns no imports/stylesheets while the dev server
# runs (the browser resolves them over HTTP via the module graph).
case_run("dev_js_tag") { VIEW.vite_javascript_tag("application") }
case_run("dev_js_tag_skip_flags") do
  VIEW.vite_javascript_tag("application", skip_preload_tags: true, skip_style_tags: true)
end
case_run("dev_js_tag_two_entries") { VIEW.vite_javascript_tag("application", "second") }
case_run("dev_css_tag") { VIEW.vite_stylesheet_tag("print") }
case_run("dev_client_src") { ViteRuby.instance.manifest.vite_client_src }
case_run("dev_client_tag") { VIEW.vite_client_tag }
case_run("dev_react_preamble_code") { ViteRuby.instance.manifest.react_preamble_code }
case_run("dev_react_refresh_tag") { VIEW.vite_react_refresh_tag }
