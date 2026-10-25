# Behavioral spec: button_to byte shape under the edge/8.2 gate
# (UrlHelper.button_to_edge_82). The 8.1.4 gem shape is covered by the
# url_button_* oracle cases (default off); rails 8.2 (the app oracle)
# reorders the form attributes action → class → method and emits a plain
# <input name="_method" type="hidden" value="..."> (no autocomplete, no
# self-closing slash).

require "spec"
require "../src/action_view_cr"

class ButtonCtx
  include ActionView::Helpers
end

BTN_CTX = ButtonCtx.new

describe ActionView::Helpers::UrlHelper do
  around_each do |example|
    old = ActionView::Helpers::UrlHelper.button_to_edge_82
    example.run
    ActionView::Helpers::UrlHelper.button_to_edge_82 = old
  end

  it "8.1 default keeps class → method → action and __av_method_field" do
    ActionView::Helpers::UrlHelper.button_to_edge_82 = false
    BTN_CTX.button_to("Del", "/d", method: "delete").to_s.should eq(
      %(<form class="button_to" method="post" action="/d"><input type="hidden" name="_method" value="delete" autocomplete="off" /><input type="submit" value="Del" /></form>))
  end

  it "edge/8.2 reorders the form tag and the _method input" do
    ActionView::Helpers::UrlHelper.button_to_edge_82 = true
    BTN_CTX.button_to("Del", "/d", method: "delete").to_s.should eq(
      %(<form action="/d" class="button_to" method="post"><input name="_method" type="hidden" value="delete"><input type="submit" value="Del" /></form>))
    BTN_CTX.button_to("/rooms/5", method: "delete", class: "btn") { "Go" }.to_s.should eq(
      %(<form action="/rooms/5" class="button_to" method="post"><input name="_method" type="hidden" value="delete"><button class="btn" type="submit">Go</button></form>))
    BTN_CTX.button_to("/go", class: "btn") { "Go" }.to_s.should eq(
      %(<form action="/go" class="button_to" method="post"><button class="btn" type="submit">Go</button></form>))
  end

  it "edge/8.2 sorts the submit <button> attributes (oracle involvement button)" do
    ActionView::Helpers::UrlHelper.button_to_edge_82 = true
    BTN_CTX.button_to("/rooms/5/involvement?involvement=everything", method: "put",
      role: "checkbox", aria: {checked: true, labelledby: "involvement_label_rooms_open_5"},
      tabindex: 0, class: "btn everything") { "Bell" }.to_s.should eq(
      %(<form action="/rooms/5/involvement?involvement=everything" class="button_to" method="post"><input name="_method" type="hidden" value="put"><button aria-checked="true" aria-labelledby="involvement_label_rooms_open_5" class="btn everything" role="checkbox" tabindex="0" type="submit">Bell</button></form>))
  end
end
