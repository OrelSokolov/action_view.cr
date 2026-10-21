# Behavioral specs: RecordIdentifier.dom_id for namespaced (STI) classes
# and the static AssetTagHelper.image_tag entry point. No oracle cases —
# the gem harness has no namespaced model wired; Rails semantics are
# dom_class = model_name.singular_route_key ('/' → '_').

require "spec"
require "../src/action_view_cr"

module Rooms
  class Open
    property id : Int64?

    def initialize(@id)
    end
  end
end

class PlainPost
  property id : Int64?

  def initialize(@id)
    end
end

describe ActionView::Helpers::RecordIdentifier do
  it "dom_id uses namespace-underscore for STI classes (Rooms::Open → rooms_open)" do
    record = Rooms::Open.new(5_i64)
    ActionView::Helpers::RecordIdentifier.dom_id(record).should eq "rooms_open_5"
    ActionView::Helpers::RecordIdentifier.dom_id(record, "involvement").should eq "involvement_rooms_open_5"
  end

  it "dom_id stays plain for non-namespaced classes" do
    ActionView::Helpers::RecordIdentifier.dom_id(PlainPost.new(7_i64)).should eq "plain_post_7"
  end

  it "dom_id new records use the new_ prefix" do
    ActionView::Helpers::RecordIdentifier.dom_id(PlainPost.new(nil)).should eq "new_plain_post"
    ActionView::Helpers::RecordIdentifier.dom_id(Rooms::Open.new(nil)).should eq "new_rooms_open"
  end
end

class StaticAssetView
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::TagHelper
end

describe "static AssetTagHelper.image_tag" do
  view = StaticAssetView.new

  it "is byte-identical to the instance form" do
    static = ActionView::Helpers::AssetTagHelper.image_tag("/assets/icon.svg",
      {"aria" => {"hidden" => "true"}, "size" => "20x20", "class" => "colorize--black"}).to_s
    instance = view.image_tag("/assets/icon.svg",
      aria: {"hidden" => "true"}, size: "20x20", class: "colorize--black").to_s
    static.should eq instance
    static.should eq %(<img src="/assets/icon.svg" width="20" height="20" aria-hidden="true" class="colorize--black" />)
  end

  it "keeps absolute sources as-is" do
    ActionView::Helpers::AssetTagHelper.image_tag("/assets/x.svg").to_s
      .should eq %(<img src="/assets/x.svg" />)
  end
end
