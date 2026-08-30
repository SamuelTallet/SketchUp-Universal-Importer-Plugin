# Universal Importer extension for SketchUp 2017 or newer.
# Copyright: © 2026 Samuel Tallet <samuel.tallet at gmail dot com>
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

  # Coplanar faces helper for SketchUp models.
  #
  # The native "Soften Edges" panel does this in one click, but has no equivalent in the Ruby
  # API, hence the edge by edge walk below.
  # @see https://github.com/SketchUp/api-issue-tracker/issues/1093
  module Coplanar

    # Two faces are taken as coplanar as long as their normals stay within this angle of each other.
    # The facets of a curved surface are 360 / segments degrees apart, and a single segment chamfer
    # on a right angle is 45 degrees: no single tolerance hides the first and keeps the second.

    # For the CAD models, tessellated fine enough to keep their chamfers.
    CAD_ANGLE_TOLERANCE = 30.degrees

    # For the meshes, coarse enough to trade their single segment chamfers for their facets.
    MESH_ANGLE_TOLERANCE = 60.degrees

    # Smooths the coplanar faces of a component, and of the groups and components nested in it.
    #
    # The edges left by a tessellation inside a flat or barely curved surface are hidden, so this
    # surface looks like the single face it stands for, while the edges that draw the shape of the
    # model keep their crispness.
    #
    # @param [Sketchup::ComponentInstance] component
    # @param [Numeric] angle_tolerance In radians.
    #
    # @raise [ArgumentError]
    def self.smooth(component, angle_tolerance)
      raise ArgumentError, 'component must be a Sketchup::ComponentInstance' \
        unless component.is_a?(Sketchup::ComponentInstance)

      raise ArgumentError, 'angle tolerance must be a Numeric' \
        unless angle_tolerance.is_a?(Numeric)

      model = Sketchup.active_model
      model.start_operation(TRANSLATE['Soften Coplanar Faces'], disable_ui=true)

      begin
        smooth_entities(component.definition.entities, angle_tolerance)
        model.commit_operation
      rescue StandardError => exception
        model.abort_operation
        puts "Error smoothing #{component.definition.name}: #{exception.message}"
      end
    end

    # Smooths the coplanar faces found in entities, and in the groups and components nested in them.
    #
    # @param [Sketchup::Entities] entities
    # @param [Numeric] angle_tolerance In radians.
    def self.smooth_entities(entities, angle_tolerance)
      entities.each do |entity|

        if entity.is_a?(Sketchup::Edge)
          soften(entity) if edge?(entity, angle_tolerance)
        elsif entity.is_a?(Sketchup::Group)
          smooth_entities(entity.entities, angle_tolerance)
        elsif entity.is_a?(Sketchup::ComponentInstance)
          smooth_entities(entity.definition.entities, angle_tolerance)
        end

      end
    end

    # Whether an edge joins exactly two faces lying, within the angle tolerance, in a same plane.
    #
    # @param [Sketchup::Edge] edge
    # @param [Numeric] angle_tolerance In radians.
    #
    # @return [Boolean]
    def self.edge?(edge, angle_tolerance)
      faces = edge.faces
      # Two faces are needed to compare their planes, so loose, bordering
      # and non-manifold edges are left alone.
      return false unless faces.size == 2

      # Two faces sharing an edge and heading nearly the same way stand for a single surface. The
      # angle is unsigned, so two faces turning their backs on each other are 180 degrees apart,
      # hence shaded apart, as they should be.
      faces[0].normal.angle_between(faces[1].normal) <= angle_tolerance
    end
    private_class_method :edge?

    # Softens and smooths an edge.
    #
    # @param [Sketchup::Edge] edge
    def self.soften(edge)
      # Softening hides the edge, yet it still holds its faces together.
      edge.soft = true
      # Smoothing shades the faces it joins as a whole.
      edge.smooth = true
    end
    private_class_method :soften

  end

end
