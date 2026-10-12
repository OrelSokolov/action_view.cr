# EmbedHelper — CRails-расширение: инлайн SVG из assets root по
# logical path (propshaft-семантика, как Static-мидлварь railties).

require "spec"
require "../src/action_view_cr"

module ActionView
  module Helpers
    class EmbedCtx
      include Helpers
    end
  end
end

EMBED_CTX = ActionView::Helpers::EmbedCtx.new

def with_embed_fixtures(&)
  old_root = ActionView::Helpers::EmbedFileHelper.assets_root
  ActionView::Helpers::EmbedFileHelper.assets_root = "#{__DIR__}/fixtures/assets"
  yield
ensure
  if old_root
    ActionView::Helpers::EmbedFileHelper.assets_root = old_root
  end
end

describe "embed_file" do
  it "inlines svg by logical path found in a subdir of assets root" do
    with_embed_fixtures do
      EMBED_CTX.embed_file("tether.svg").raw.should eq(
        %(<svg viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">\n) +
        %(  <circle cx="16" cy="16" r="16" fill="#26A17B"/>\n</svg>\n))
    end
  end

  it "keeps xml prolog before the root svg tag" do
    with_embed_fixtures do
      result = EMBED_CTX.embed_file("menu.svg").raw
      result.should start_with(%(<?xml version="1.0" encoding="UTF-8"?>\n<svg))
    end
  end

  it "injects options into the root svg tag, overriding same-named attrs" do
    with_embed_fixtures do
      result = EMBED_CTX.embed_file("menu.svg", class: "icon icon-menu", width: 16).raw
      result.should contain(
        %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" ) +
        %(fill="none" stroke="currentColor" class="icon icon-menu" width="16">))
    end
  end

  it "raises ArgumentError when the asset is not found" do
    with_embed_fixtures do
      expect_raises(ArgumentError, /missing\.svg/) do
        EMBED_CTX.embed_file("missing.svg")
      end
    end
  end

  it "returns SafeString" do
    with_embed_fixtures do
      EMBED_CTX.embed_file("tether.svg").should be_a(ActionView::SafeString)
    end
  end
end
