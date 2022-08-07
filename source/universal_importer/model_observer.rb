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
require 'universal_importer/components'

# Universal Importer plugin namespace.
module UniversalImporter

  # Observes SketchUp model events and reacts.
  class ModelObserver < Sketchup::ModelObserver

    # When a component is “placed” into the model:
    def onPlaceComponent(component)

      # Scales component according to user input.
      if !SESSION[:model_height_in_mm].nil?

        Components.scale_down(component, SESSION[:model_height_in_mm])

        SESSION[:model_height_in_mm] = nil

        Sketchup.active_model.active_view.zoom_extents

      end

      # Names component with source filename.
      if !SESSION[:source_filename].nil?

        component.definition.name = SESSION[:source_filename]

        SESSION[:source_filename] = nil

      end

      # Displays face count before/after reduction.
      if !SESSION[:faces_num_before_reduc].nil?

        UI.messagebox(

          TRANSLATE['Face count before reduction:'] + ' ' +
          SESSION[:faces_num_before_reduc].to_s + "\n" +

          TRANSLATE['Face count after reduction:'] + ' ' +
          (Sketchup.active_model.number_faces\
            - SESSION[:faces_num_before_reduc]).to_s
          
        )

        SESSION[:faces_num_before_reduc] = nil

      end

      if Donate.invitation_planned?
        Donate.invite_user
        Donate.invitation_planned = false
      end

    end

  end

end
