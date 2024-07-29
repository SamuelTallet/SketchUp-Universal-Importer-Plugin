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

  # Orientation helper for 3D models.
  module Orientation

    # Rotates a component from its origin point.
    #
    # @param [Sketchup::ComponentInstance] component
    # @param [Geom::Vector3d] axis Rotation axis.
    # @param [Float] angle Rotation angle in radians.
    # @raise [ArgumentError]
    def self.rotate(component, axis, angle)
      raise ArgumentError, 'component must be a Sketchup::ComponentInstance' \
        unless component.is_a?(Sketchup::ComponentInstance)

      raise ArgumentError, 'axis must be a Geom::Vector3d' \
        unless axis.is_a?(Geom::Vector3d)

      raise ArgumentError, 'angle must be a Float' \
        unless angle.is_a?(Float)

      # @type [Geom::Point3d]
      point = component.transformation.origin
      rotation = Geom::Transformation.rotation(point, axis, angle)

      model = Sketchup.active_model
      model.start_operation(TRANSLATE['Rotate Component'], disable_ui=true)

      begin
        component.transform!(rotation)
        model.commit_operation
      rescue StandardError => exception
        model.abort_operation
        puts "Error rotating #{component.definition.name}: #{exception.message}"
      end
    end

  end

end
