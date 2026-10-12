# Mirror of oracle/vite_expected.yml (captured from vite_rails 3.0.19 /
# vite_ruby 3.9.2 via oracle/vite_cases.rb — the versions qp2/website
# pins). Same case IDs, same expectations. The fixture manifest mirrors
# a real `vite build` output (vite 5/6 format).

require "spec"
require "../src/action_view_cr"
require "file_utils"

VITE_EXPECTED = begin
  hash = {} of String => String
  File.read("#{__DIR__}/../oracle/vite_expected.yml").each_line do |line|
    next unless line.includes?('\t')
    id, value = line.split('\t', 2)
    hash[id] = value.chomp.gsub("\\n", "\n")
  end
  hash
end

FIXTURE = File.join(Dir.tempdir, "crails_vite_spec_#{Random::Secure.hex(4)}")
FileUtils.mkdir_p(File.join(FIXTURE, "public/vite/.vite"))

File.write(File.join(FIXTURE, "public/vite/.vite/manifest.json"), <<-JSON)
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

ViteRuby::Manifest.path = File.join(FIXTURE, "public/vite/.vite/manifest.json")
# Production-кейсы ниже детерминированы: без подмены дев-детект
#.lookup ходил бы в TCP-пробу 127.0.0.1:5173.
ViteRuby.dev_server_running = false
# Spec examples run at_exit — after the cleanup below. Load eagerly
# while the fixture still exists.
ViteRuby.manifest

# Контекст рендера, дающий хелперам единый self (как контроллер).
class ViteSpecContext
  include ActionView::Helpers
end

VITE_VIEW = ViteSpecContext.new

def vite_case(id)
  begin
    yield
  rescue ex : ViteRuby::MissingEntrypointError
    "raise:#{ex.class.name}"
  rescue ex : ArgumentError
    "raise:#{ex.class.name}"
  end.to_s
end

describe "vite_rails helpers (vite_rails 3.0.19 oracle)" do
  it "path_js_entry" do
    vite_case("x") { VITE_VIEW.vite_asset_path("application", "javascript") }
      .should eq VITE_EXPECTED["path_js_entry"]
  end

  it "path_css_nested" do
    vite_case("x") { VITE_VIEW.vite_asset_path("styles/admin.css") }
      .should eq VITE_EXPECTED["path_css_nested"]
  end

  it "path_source_dir" do
    vite_case("x") { VITE_VIEW.vite_asset_path("~/src/nested.js") }
      .should eq VITE_EXPECTED["path_source_dir"]
  end

  it "path_image" do
    vite_case("x") { VITE_VIEW.vite_asset_path("images/logo-789.png") }
      .should eq VITE_EXPECTED["path_image"]
  end

  it "path_without_type_missing" do
    vite_case("x") { VITE_VIEW.vite_asset_path("application") }
      .should eq VITE_EXPECTED["path_without_type_missing"]
  end

  it "path_missing_entry" do
    vite_case("x") { VITE_VIEW.vite_asset_path("nope.js") }
      .should eq VITE_EXPECTED["path_missing_entry"]
  end

  it "js_tag" do
    vite_case("x") { VITE_VIEW.vite_javascript_tag("application") }
      .should eq VITE_EXPECTED["js_tag"]
  end

  it "js_tag_no_preload_no_styles" do
    vite_case("x") { VITE_VIEW.vite_javascript_tag("application", skip_preload_tags: true, skip_style_tags: true) }
      .should eq VITE_EXPECTED["js_tag_no_preload_no_styles"]
  end

  it "js_tag_two_entries" do
    vite_case("x") { VITE_VIEW.vite_javascript_tag("application", "second") }
      .should eq VITE_EXPECTED["js_tag_two_entries"]
  end

  it "css_tag" do
    vite_case("x") { VITE_VIEW.vite_stylesheet_tag("print") }
      .should eq VITE_EXPECTED["css_tag"]
  end

  it "css_tag_nested" do
    vite_case("x") { VITE_VIEW.vite_stylesheet_tag("styles/admin.css") }
      .should eq VITE_EXPECTED["css_tag_nested"]
  end

  it "image_tag" do
    vite_case("x") { VITE_VIEW.vite_image_tag("images/logo-789.png") }
      .should eq VITE_EXPECTED["image_tag"]
  end

  it "client_tag_dev_off" do
    VITE_VIEW.vite_client_tag.to_s.should eq VITE_EXPECTED["client_tag_dev_off"]
  end

  it "react_refresh_dev_off" do
    VITE_VIEW.vite_react_refresh_tag.to_s.should eq VITE_EXPECTED["react_refresh_dev_off"]
  end

  it "js_tag_missing" do
    vite_case("x") { VITE_VIEW.vite_javascript_tag("nope") }
      .should eq VITE_EXPECTED["js_tag_missing"]
  end
end

# --- dev-режим (оракул oracle/vite_dev_expected.yml, снят с настоящих
# vite_rails 3.0.19 / vite_ruby 3.9.2 против TCP-заглушки dev-сервера;
# vite_ruby#dev_server_running? — реальная проба) ------------------------
VITE_DEV_EXPECTED = begin
  hash = {} of String => String
  File.read("#{__DIR__}/../oracle/vite_dev_expected.yml").each_line do |line|
    next unless line.includes?('\t')
    id, value = line.split('\t', 2)
    hash[id] = value.chomp.gsub("\\n", "\n")
  end
  hash
end

describe "vite_rails helpers in dev mode (vite_rails 3.0.19 oracle)" do
  before_all do
    ViteRuby.dev_server_running = true
  end

  after_all do
    ViteRuby.dev_server_running = false
  end

  it "dev_path_js_entry" do
    VITE_VIEW.vite_asset_path("application", "javascript")
      .should eq VITE_DEV_EXPECTED["dev_path_js_entry"]
  end

  it "dev_path_without_type" do
    VITE_VIEW.vite_asset_path("application")
      .should eq VITE_DEV_EXPECTED["dev_path_without_type"]
  end

  it "dev_path_source_dir" do
    VITE_VIEW.vite_asset_path("~/src/nested.js")
      .should eq VITE_DEV_EXPECTED["dev_path_source_dir"]
  end

  it "dev_path_image" do
    VITE_VIEW.vite_asset_path("images/logo-789.png")
      .should eq VITE_DEV_EXPECTED["dev_path_image"]
  end

  it "dev_css_path" do
    VITE_VIEW.vite_asset_path("print", "stylesheet")
      .should eq VITE_DEV_EXPECTED["dev_css_path"]
  end

  it "dev_js_tag" do
    VITE_VIEW.vite_javascript_tag("application").to_s
      .should eq VITE_DEV_EXPECTED["dev_js_tag"]
  end

  it "dev_js_tag_skip_flags" do
    VITE_VIEW.vite_javascript_tag("application",
      skip_preload_tags: true, skip_style_tags: true).to_s
      .should eq VITE_DEV_EXPECTED["dev_js_tag_skip_flags"]
  end

  it "dev_js_tag_two_entries" do
    VITE_VIEW.vite_javascript_tag("application", "second").to_s
      .should eq VITE_DEV_EXPECTED["dev_js_tag_two_entries"]
  end

  it "dev_css_tag" do
    VITE_VIEW.vite_stylesheet_tag("print").to_s
      .should eq VITE_DEV_EXPECTED["dev_css_tag"]
  end

  it "dev_client_src" do
    ViteRuby.manifest.vite_client_src
      .should eq VITE_DEV_EXPECTED["dev_client_src"]
  end

  it "dev_client_tag" do
    VITE_VIEW.vite_client_tag.not_nil!.to_s
      .should eq VITE_DEV_EXPECTED["dev_client_tag"]
  end

  it "dev_react_preamble_code" do
    ViteRuby.manifest.react_preamble_code
      .should eq VITE_DEV_EXPECTED["dev_react_preamble_code"]
  end

  it "dev_react_refresh_tag" do
    VITE_VIEW.vite_react_refresh_tag.not_nil!.to_s
      .should eq VITE_DEV_EXPECTED["dev_react_refresh_tag"]
  end
end

FileUtils.rm_rf(FIXTURE)

# Documented deviations (also in src/helpers/vite_helper.cr):
# - dev mode is detected by a TCP probe of ViteRuby.dev_server_host:port
#   (cached 1s, like the gem's dev_server_running?); specs force it via
#   ViteRuby.dev_server_running=. The dev-server HTTP/WS proxy itself
#   lives in railties.cr (CRails::Middleware::ViteDevProxy).
# - config: class properties (ViteRuby::Manifest.path etc.) + env
#   CRAILS_VITE_MANIFEST / CRAILS_VITE_HOST / CRAILS_VITE_PORT;
#   config/vite.json is not parsed; no auto_build.
# - type: is a String? here ("javascript"/"stylesheet"), the gem uses
#   Symbols — documented NamedTuple-style deviation for Crystal.
# - absolute entries ("/...") lose the leading slash in dev too (no
#   /@fs/ prefix like the gem's resolve_absolute_entry).
