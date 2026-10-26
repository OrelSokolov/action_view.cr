# Behavioral spec: button_to byte shape vs the RAW actionview gem
# (both 8.1.4 and the app oracle's 8.2.0.alpha git ref — the code is
# identical here). Guards against chasing the parity harness's artifact
# normalization: capybara-tests/harness/normalize.rb SORTS tag attributes
# when saving artifacts, so saved HTML shows alphabetical order that the
# gem never emits. Real bytes: form tag class → method → action, method
# field through __av_method_field (autocomplete gated by
# method_field_autocomplete — load_defaults 8.2 apps set it false),
# submit <button> attrs in insertion order with type appended,
# boolean attrs as key="key" (hidden="hidden").

require "spec"
require "../src/action_view_cr"

class ButtonCtx
  include ActionView::Helpers
end

BTN_CTX = ButtonCtx.new

describe ActionView::Helpers::UrlHelper do
  around_each do |example|
    old = ActionView::Helpers::FormTagHelper.method_field_autocomplete
    example.run
    ActionView::Helpers::FormTagHelper.method_field_autocomplete = old
  end

  it "insertion order everywhere (raw gem bytes, NOT the sorted artifacts)" do
    ActionView::Helpers::FormTagHelper.method_field_autocomplete = false
    BTN_CTX.button_to("/rooms/5/involvement?involvement=everything", method: "put",
      role: "checkbox", aria: {checked: true, labelledby: "involvement_label_rooms_open_5"},
      tabindex: 0, class: "btn everything") { "Bell" }.to_s.should eq(
      %(<form class="button_to" method="post" action="/rooms/5/involvement?involvement=everything"><input type="hidden" name="_method" value="put" /><button role="checkbox" aria-checked="true" aria-labelledby="involvement_label_rooms_open_5" tabindex="0" class="btn everything" type="submit">Bell</button></form>))
  end

  it "load_defaults 8.1 keeps autocomplete on the _method input" do
    ActionView::Helpers::FormTagHelper.method_field_autocomplete = true
    BTN_CTX.button_to("/d", method: "delete") { "Go" }.to_s.should eq(
      %(<form class="button_to" method="post" action="/d"><input type="hidden" name="_method" value="delete" autocomplete="off" /><button type="submit">Go</button></form>))
  end
end
