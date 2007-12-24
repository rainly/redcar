
module Redcar
  module Plugins
    module PluginManager
      extend FreeBASE::StandardPlugin
      extend Redcar::PreferencesBuilder
      extend Redcar::CommandBuilder
      extend Redcar::MenuBuilder
      
      preference "Plugins/Plugin Manager/Warn me about reloading" do |p|
        p.type = :toggle
        p.default = true
      end
      
      command "Plugin Manager/Open" do |c|
        c.menu = "Tools/Plugin Manager"
        c.icon = :PREFERENCES
        c.command =<<-RUBY
          new_tab = Redcar.new_tab(Redcar::PluginTab)
          new_tab.focus
          new_tab.name = "Plugin Manager"
          Redcar.StatusBar.main = "Opened Plugin Manager"
        RUBY
      end
    end
  end
  
  class PluginTab < Tab
    def initialize(pane)
      @ts = Gtk::ListStore.new(String, String, String)
      @tv = Gtk::TreeView.new(@ts)
      renderer = Gtk::CellRendererText.new
      col1 = Gtk::TreeViewColumn.new("Name", renderer, :text => 0)
      col2 = Gtk::TreeViewColumn.new("Version", renderer, :text => 1)
      col3 = Gtk::TreeViewColumn.new("State", renderer, :text => 2)
      @tv.append_column(col1)
      @tv.append_column(col2)
      @tv.append_column(col3)
      @tv.show
      super(pane, @tv, :scrolled => true, :toolbar? => true)
      build_tree
      build_menu
      @tv.signal_connect("button_press_event") do |_, event|
        if (event.button == 3)
          @menu.popup(nil, nil, event.button, event.time)
        end
      end
      
      self.toolbar.append("Info", "", "", Redcar.Icon.get_image(:INFO)) do
        info((@tv.selection.selected||[])[0])
      end
      
      self.toolbar.append("Reload", "", "", Redcar.Icon.get_image(:REFRESH)) do
        reload((@tv.selection.selected||[])[0])
      end
      
      self.toolbar.append("Test", "", "", Redcar.Icon.get_image(:EXECUTE)) do 
        test((@tv.selection.selected||[])[0])
      end
      
      self.toolbar.append("Test All", "", "", Redcar.Icon.get_image(:EXECUTE)) do 
        puts "\nTesting all plugins:"
        @ts.each do |_, _, iter|
          test(iter[0])
        end
      end
    end
    
    def build_menu
      @menu = Gtk::Menu.new
      item_reload = Gtk::MenuItem.new("Reload")
      item_info   = Gtk::MenuItem.new("Info")
      item_test   = Gtk::MenuItem.new("Test")
      @menu.append(item_reload)
      @menu.append(item_info)
      @menu.append(item_test)
      @menu.show_all
      
      item_info.signal_connect("activate") do
        info((@tv.selection.selected||[])[0])
      end
      
      item_reload.signal_connect("activate") do
        reload((@tv.selection.selected||[])[0])
      end
      
      item_test.signal_connect("activate") do
        test((@tv.selection.selected||[])[0])
      end
    end

    def info(plugin)
      return if plugin.blank?
      slot = $BUS['/plugins/'+plugin]
      string =<<END
Name: #{slot.name}
Version: #{slot['info/version'].data}
Author: #{slot['info/author'].data}
Description: #{slot['info/description'].data}
Files: #{((slot['files/plugin'].data||[])+(slot['files/test'].data||[])).length}
END
      dialog = Gtk::MessageDialog.new(Redcar.current_window, 
                                      Gtk::Dialog::DESTROY_WITH_PARENT,
                                      Gtk::MessageDialog::INFO,
                                      Gtk::MessageDialog::BUTTONS_CLOSE,
                                      string)
      dialog.title = "Plugin Information"
      dialog.run
      dialog.destroy
    end
    
    def reload(plugin)
      return if plugin.blank?
      continue = true
      if Redcar.preferences("Plugins/Plugin Manager/Warn me about reloading").to_bool
        message=<<END
Reloading a plugin can have strange effects, including causing Redcar
to crash. Are you sure you would like to reload this plugin?
END
        dialog = Gtk::Dialog.new("Are you sure?",
                                 Redcar.current_window, 
                                 Gtk::Dialog::DESTROY_WITH_PARENT,
                                 [ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK ],
                                 [ Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL]
                                 )
        dialog.vbox.add(Gtk::Label.new(message))
        toggle = Gtk.CheckButton.new("Warn me about this.")
        toggle.active = true
        dialog.vbox.add(toggle)
        dialog.show_all
        dialog.title = "Are you sure?"
        case dialog.run 
        when Gtk::Dialog::RESPONSE_OK
          continue = true
        when Gtk::Dialog::RESPONSE_CANCEL
          continue = false
        end
        Redcar.set_preference("Plugins/Plugin Manager/Warn me about reloading", toggle.active?)
        dialog.destroy
      end
      if continue
        $BUS['/plugins/'+plugin+"/actions/reload"].call
      end
    end
    
    def test(plugin)
      return if plugin.blank?
      plugin_slot = $BUS['/plugins/'+plugin]
      if plugin_slot["actions"].has_child?("test")
        plugin_slot["actions/test"].call
      else
        puts "No tests for #{plugin}"
      end
    end
    
    def build_tree
      plugins_slot = $BUS['/plugins']
      plugins_slot.each_slot do |plugin_slot|
        iter = @ts.append
        @ts.set_value(iter, 0, plugin_slot.name)
        @ts.set_value(iter, 1, plugin_slot['info/version'].data.to_s)
        @ts.set_value(iter, 2, plugin_slot['state'].data.to_s.downcase)
      end
    end
  end
end
