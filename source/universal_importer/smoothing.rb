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

  # Edges smoothing helper for SketchUp models.
  module Smoothing

    # Softens and smooths the edges of a component.
    #
    # @param [Sketchup::ComponentInstance] component
    # @param [Boolean] recursive Whether the groups and components nested in this one are processed too.
    # @param [Boolean] soft Whether the edges are softened: hidden, yet still holding their faces together.
    # @param [Boolean] smooth Whether the edges are smoothed: the faces they join are shaded as a whole.
    #
    # @raise [ArgumentError]
    def self.apply(component, recursive = true, soft = true, smooth = true)
      raise ArgumentError, 'component must be a Sketchup::ComponentInstance' \
        unless component.is_a?(Sketchup::ComponentInstance)
      raise ArgumentError, 'recursive must be a Boolean' \
        unless recursive == true || recursive == false
      raise ArgumentError, 'soft must be a Boolean' \
        unless soft == true || soft == false
      raise ArgumentError, 'smooth must be a Boolean' \
        unless smooth == true || smooth == false

      model = Sketchup.active_model
      model.start_operation(TRANSLATE['Smooth Component'], disable_ui=true)

      begin
        apply_to_entities(component.definition.entities, recursive, soft, smooth)
        model.commit_operation
      rescue StandardError => exception
        model.abort_operation
        puts "Error smoothing #{component.definition.name}: #{exception.message}"
      end
    end

    # Softens and smooths the edges found in entities.
    #
    # @param [Sketchup::Entities] entities
    # @param [Boolean] recursive
    # @param [Boolean] soft
    # @param [Boolean] smooth
    def self.apply_to_entities(entities, recursive, soft, smooth)
      entities.each do |entity|

        if entity.is_a?(Sketchup::Edge)
          # Softening hides an edge, smoothing blends the shading of the faces it joins: both
          # need exactly two faces, so loose, bordering and non-manifold edges are left alone.
          next unless entity.faces.size == 2

          entity.soft = soft
          entity.smooth = smooth
        elsif recursive
          if entity.is_a?(Sketchup::Group)
            apply_to_entities(entity.entities, recursive, soft, smooth)
          elsif entity.is_a?(Sketchup::ComponentInstance)
            apply_to_entities(entity.definition.entities, recursive, soft, smooth)
          end
        end

      end
    end
    private_class_method :apply_to_entities

  end

end
