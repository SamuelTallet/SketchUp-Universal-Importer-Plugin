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

# Universal Importer plugin namespace.
module UniversalImporter

  # Length units helper for 3D models.
  module Units

    # Supported units.
    MILLIMETERS = :mm
    CENTIMETERS = :cm
    METERS = :m
    INCHES = :in
    FEET = :ft
    YARDS = :yd

    # Conversion table, from xy units to meters.
    AS_METERS = {
      :mm => 0.001,
      :cm => 0.01,
      :in => 0.0254,
      :ft => 0.3048,
      :yd => 0.9144
    }

    # Returns the most probable units for a given file extension.
    #
    # @param [String] file_extension
    # @return [Symbol]
    def self.guess_by(file_extension)
      case file_extension
      when '3mf', 'brep', 'dxf', 'iges', 'igs', 'step', 'stp', 'stl'
        MILLIMETERS
      when 'fbx'
        CENTIMETERS
      when '3ds'
        INCHES
      else # gltf, blend, lwo, wrl, dae, obj, etc.
        METERS
      end
    end

    # Assuming it is in meters, resizes a component to be in other units.
    #
    # @param [Sketchup::ComponentInstance] component
    # @param [Symbol] units
    # @raise [ArgumentError]
    def self.change(component, units)
      raise ArgumentError, 'component must be a Sketchup::ComponentInstance' \
        unless component.is_a?(Sketchup::ComponentInstance)

      raise ArgumentError, "units must be one of #{AS_METERS.keys.join(', ')}" \
        unless AS_METERS.include?(units)

      # Scale factor as meters.
      # @type [Float]
      scale = AS_METERS[units]
      scaling = Geom::Transformation.scaling(scale, scale, scale)

      model = Sketchup.active_model
      model.start_operation(TRANSLATE['Change Component Units'], disable_ui=true)
      
      begin
        component.transform!(scaling)
        # Zooms to the extent of the component instance for user convenience.
        model.active_view.zoom(component)

        model.commit_operation
      rescue StandardError => exception
        model.abort_operation
        puts "Error scaling #{component.definition.name}: #{exception.message}"
      end
    end

  end

end
