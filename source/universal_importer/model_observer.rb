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

require 'sketchup'
require 'universal_importer/import'
require 'universal_importer/poly_reduction'
require 'universal_importer/donate'

# Universal Importer plugin namespace.
module UniversalImporter

  # Observes SketchUp model events and reacts...
  class ModelObserver < Sketchup::ModelObserver

    # When a component is “placed” into the model:
    def onPlaceComponent(component)

      if !Import.last.nil? && Import.last.completed
        Import.last.delete_temp_files
        component.definition.name = Import.last.source_filename
        Import.last = nil
      end

      if !PolyReduction.last.nil? && PolyReduction.last.completed
        PolyReduction.last.delete_temp_dir
        PolyReduction.last.show_face_count_summary
        PolyReduction.last = nil
      end

      if Donate.invitation_planned?
        Donate.invite_user
        Donate.invitation_planned = false
      end

    end

  end

end
