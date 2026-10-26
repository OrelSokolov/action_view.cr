# Behavioral spec: FormBuilder#rich_text_area / rich_textarea_tag —
# the Rails 8.2 ActionText lexxy editor surface. The <lexxy-editor>
# custom element with class defaulting to "lexxy-content", scope-derived
# name/id (ids gated by form_with_generates_ids, explicit id: wins),
# explicit value: beating the object attribute, data-direct-upload-url /
# data-blob-url-template defaulting from the host view context (nil →
# omitted), and the block body (mention prompts) passed through unescaped.

require "spec"
require "../src/action_view_cr"

class RichTextCtx
  include ActionView::Helpers

  def rich_text_direct_upload_url : String
    "http://x.test/rails/active_storage/direct_uploads"
  end

  def rich_text_blob_url_template : String
    "http://x.test/rails/active_storage/blobs/redirect/:signed_id/:filename"
  end
end

RT_CTX = RichTextCtx.new

class RtMessage
  include ActionView::FormModel

  def form_scope : String
    "message"
  end

  def form_attributes : Hash(String, ActionView::FormValue)
    {"body" => nil} of String => ActionView::FormValue
  end

  def form_persisted? : Bool
    false
  end

  def form_model_name : String
    "message"
  end
end

describe ActionView::Helpers::FormHelper do
  around_each do |example|
    ids = ActionView::Helpers::FormHelper.form_with_generates_ids
    remote = ActionView::Helpers::FormHelper.form_with_generates_remote_forms
    utf8 = ActionView::Helpers::FormTagHelper.default_enforce_utf8
    ActionView::Helpers::FormHelper.form_with_generates_remote_forms = false
    ActionView::Helpers::FormTagHelper.default_enforce_utf8 = false
    example.run
    ActionView::Helpers::FormHelper.form_with_generates_ids = ids
    ActionView::Helpers::FormHelper.form_with_generates_remote_forms = remote
    ActionView::Helpers::FormTagHelper.default_enforce_utf8 = utf8
  end

  it "rich_text_area: defaults (class, name, data URLs) + block prompt" do
    ActionView::Helpers::FormHelper.form_with_generates_ids = true
    out = RT_CTX.capture do
      RT_CTX.form_with(model: RtMessage.new, url: "/rooms/2/messages") do |form|
        form.rich_text_area :body, rows: 1, class: "input lexxy-content",
          data: {controller: "unfurl"} do
          RT_CTX.content_tag("lexxy-prompt", trigger: "@")
        end
      end
    end
    out.to_s.should eq(
      %(<form action="/rooms/2/messages" accept-charset="UTF-8" method="post">) +
      %(<lexxy-editor rows="1" class="input lexxy-content" data-controller="unfurl" ) +
      %(data-direct-upload-url="http://x.test/rails/active_storage/direct_uploads" ) +
      %(data-blob-url-template="http://x.test/rails/active_storage/blobs/redirect/:signed_id/:filename" ) +
      %(id="message_body" name="message[body]">) +
      %(<lexxy-prompt trigger="@"></lexxy-prompt></lexxy-editor></form>))
  end

  it "rich_text_area: explicit value wins, nil value omitted, no ids when disabled" do
    ActionView::Helpers::FormHelper.form_with_generates_ids = false
    out = RT_CTX.capture do
      RT_CTX.form_with(model: RtMessage.new, url: "/rooms/2/messages") do |form|
        form.rich_text_area :body, value: "<p>hi</p>"
      end
    end
    out.to_s.should eq(
      %(<form action="/rooms/2/messages" accept-charset="UTF-8" method="post">) +
      %(<lexxy-editor name="message[body]" value="&lt;p&gt;hi&lt;/p&gt;" class="lexxy-content" ) +
      %(data-direct-upload-url="http://x.test/rails/active_storage/direct_uploads" ) +
      %(data-blob-url-template="http://x.test/rails/active_storage/blobs/redirect/:signed_id/:filename"></lexxy-editor></form>))
  end

  it "rich_textarea_tag: bare tag form, no data URLs when the context has none" do
    plain = ButtonCtx.new
    plain.rich_textarea_tag("content", nil).to_s.should eq(
      %(<lexxy-editor name="content" class="lexxy-content"></lexxy-editor>))
  end
end

class ButtonCtx
  include ActionView::Helpers
end
