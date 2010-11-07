module Redcar
  class ApplicationSWT
    class Speedbar
      class ToggleItem
        def initialize(composite, item)
          button = Swt::Widgets::Button.new(composite, Swt::SWT::CHECK)
          button.set_text(item.text)
          button.set_selection(!!item.value)
          button.add_selection_listener do
            item.value = button.get_selection
            execute_listener_in_model(item, item.value)
          end
          item.add_listener(:changed_text) do |new_text|
            rescue_speedbar_errors do
              button.set_text = new_text
            end
          end
          item.add_listener(:changed_value) do |new_value|
            rescue_speedbar_errors do
              button.set_selection(!!new_value)
            end
          end
          keyable_widgets    << button
          focussable_widgets << button
        end
      end
    end
  end
end
