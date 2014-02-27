module LinkHelper
  def link_form(text, destination, options = {})
    form_tag(destination, :method => options.delete(:method)) do
      <<-HTML
        <!-- some HTML code here -->
        <button type="submit">#{text}</button>
        <!-- some more HTML code here -->
      HTML
    end
  end
end
