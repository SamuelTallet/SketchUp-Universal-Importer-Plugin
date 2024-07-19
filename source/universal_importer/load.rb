# Universal Importer extension for SketchUp 2017 or newer.
# Copyright: © 2024 Samuel Tallet <samuel.tallet at gmail dot com>
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
require 'universal_importer/mayo_conv'
require 'universal_importer/assimp'
require 'universal_importer/meshlab'
require 'universal_importer/app_observer'
require 'universal_importer/model_observer'
require 'universal_importer/menu'
require 'universal_importer/toolbar'
require 'universal_importer/donate'

# Universal Importer plugin namespace.
module UniversalImporter

  MayoConv.set_executable_path

  if Sketchup.platform == :platform_osx
    Assimp.ensure_executable
    MeshLab.ensure_executable
  end

  Sketchup.add_observer(AppObserver.new)
  Sketchup.active_model.add_observer(ModelObserver.new)

  Menu.add
  Toolbar.new.prepare.show

  Donate.fetch_url

  # Load complete.

end
