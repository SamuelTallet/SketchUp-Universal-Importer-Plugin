# Universal Importer extension for SketchUp 2017 or newer.
# Copyright: © 2019 Samuel Tallet <samuel.tallet arobase gmail.com>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3.0 of the License, or
# (at your option) any later version.
# 
# If you release a modified version of this program TO THE PUBLIC,
# the GPL requires you to MAKE THE MODIFIED SOURCE CODE AVAILABLE
# to the program's users, UNDER THE GPL.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
# 
# Get a copy of the GPL here: https://www.gnu.org/licenses/gpl.html

raise 'The UIR plugin requires at least Ruby 2.2.0 or SketchUp 2017.'\
  unless RUBY_VERSION.to_f >= 2.2 # SketchUp 2017 includes Ruby 2.2.4.

require 'sketchup'
require 'universal_importer/converter'

# Universal Importer plugin namespace.
module UniversalImporter

  # Connects Universal Importer plugin menu to SketchUp user interface.
  class Menu

    # Adds Universal Importer plugin menu in a SketchUp menu.
    #
    # @param [Sketchup::Menu] parent_menu Target parent menu.
    # @raise [ArgumentError]
    def initialize(parent_menu)

      raise ArgumentError, 'Parent menu must be a SketchUp::Menu.'\
        unless parent_menu.is_a?(Sketchup::Menu)

      parent_menu.add_item(TRANSLATE['Import with Universal Importer...']) {

        if Sketchup.platform == :platform_osx

          UI.messagebox(TRANSLATE['MacOS is not supported by this plugin.'])
          return

        end

        Converter.new

      }

    end

  end

end
