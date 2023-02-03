# Universal Importer extension for SketchUp 2017 or newer.
# Copyright: © 2023 Samuel Tallet <samuel.tallet at gmail dot com>
# 
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 3.0 of the License, or (at your option) any later version.
# 
# If you release a modified version of this program TO THE PUBLIC, the GPL requires you to MAKE THE MODIFIED SOURCE CODE
# AVAILABLE to the program's users, UNDER THE GPL.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# Get a copy of the GPL here: https://www.gnu.org/licenses/gpl.html

require 'fileutils'
require 'sketchup'
require 'universal_importer/polyreduction'

# Universal Importer plugin namespace.
module UniversalImporter

  # Toolbar of Universal Importer plugin.
  class Toolbar

    # Absolute path to icons.
    ICONS_PATH = File.join(__dir__, 'Toolbar Icons').freeze

    private_constant :ICONS_PATH

    # Initializes instance.
    def initialize

      @toolbar = UI::Toolbar.new(PLUGIN_NAME)

    end

    # Returns extension of icons depending on platform...
    #
    # @return [String] Extension. PDF (Mac) or SVG (Win).
    private def icon_extension

      if Sketchup.platform == :platform_osx
        '.pdf'
      else
        '.svg'
      end

    end

    # Adds "Reduce Polygon Count..." command.
    private def add_reduce_polygon_count

      command = UI::Command.new('rpc') do
        PolyReduction.last = PolyReduction.new
      end

      command.small_icon = File.join(ICONS_PATH, 'rpc'.concat(icon_extension))
      command.large_icon = File.join(ICONS_PATH, 'rpc'.concat(icon_extension))
      command.tooltip = TRANSLATE['Reduce Polygon Count...']

      @toolbar.add_item(command)

    end

    # Prepares.
    #
    # @return [UI::Toolbar] Toolbar instance.
    def prepare

      add_reduce_polygon_count

      @toolbar

    end

  end

end
