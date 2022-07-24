# Universal Importer extension for SketchUp 2017 or newer.
# Copyright: © 2022 Samuel Tallet <samuel.tallet at gmail dot com>
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

require 'sketchup'
require 'universal_importer/importer'

# Universal Importer plugin namespace.
module UniversalImporter

  # Connects Universal Importer plugin menu to SketchUp user interface.
  module Menu

    # Adds menu.
    def self.add

      file_menu = UI.menu('File')

      file_menu.add_item(TRANSLATE['Import with'] + ' ' + NAME + '...') do
        Importer.new
      end

      plugin_menu = UI.menu('Plugins').add_submenu(NAME)

      plugin_menu.add_item(TRANSLATE['Import a 3D Model...']) do
        Importer.new
      end

      ppr_menu_item = plugin_menu.add_item(TRANSLATE['Propose Polygon Reduction']) do
        Importer.propose_polygon_reduction = !Importer.propose_polygon_reduction?
      end

      plugin_menu.set_validation_proc(ppr_menu_item) do
        Importer.propose_polygon_reduction? ? MF_CHECKED : MF_UNCHECKED
      end

      cmt_menu_item = plugin_menu.add_item(TRANSLATE['Claim Missing Textures']) do
        Importer.claim_missing_textures = !Importer.claim_missing_textures?
      end

      plugin_menu.set_validation_proc(cmt_menu_item) do
        Importer.claim_missing_textures? ? MF_CHECKED : MF_UNCHECKED
      end

      plugin_menu.add_item('💌 ' + TRANSLATE['Donate to Plugin Author']) do
        UI.openURL('https://www.paypal.me/SamuelTallet')
      end

      plugin_menu.add_separator

      plugin_menu.add_item(TRANSLATE['Plugins of Same Author']) do
        UI.openURL('https://sketchucation.com/pluginstore?pauthor=samuel_t')
      end

    end

  end

end
