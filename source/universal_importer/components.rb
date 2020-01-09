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

# Universal Importer plugin namespace.
module UniversalImporter

  # SketchUp components.
  module Components

    # Scales down a component to a target height.
    #
    # @param [Sketchup::ComponentInstance] component
    # @param [Integer] target_height
    #
    # @raise [ArgumentError]
    #
    # @return [nil]
    def self.scale_down(component, target_height)

      raise ArgumentError, 'This isn\'t a Sketchup::ComponentInstance.'\
        unless component.is_a?(Sketchup::ComponentInstance)

      raise ArgumentError, 'This isn\'t an Integer.'\
        unless target_height.is_a?(Integer)

      component_bounds = component.bounds

      component_height = (component_bounds.max.z - component_bounds.min.z)\
        .to_l.to_cm.to_i

      return if component_height == target_height

      if component_height > target_height

        component_scale = 1

        model = Sketchup.active_model

        model.start_operation(
          TRANSLATE['Scale Imported Model'],
          true #disable_ui
        )

        loop do

          component_bounds = component.bounds

          component_height = (component_bounds.max.z - component_bounds.min.z)\
            .to_l.to_cm.to_i

          if component_scale <= 0.00001\
            || component_height.between?(target_height - 5, target_height + 5)
            
            break

          end

          component_scale -= 0.00001

          # Resets scale.
          component.transform!(
            Geom::Transformation.scaling(ORIGIN, 1.0)
          )

          component.transform!(
            Geom::Transformation.scaling(ORIGIN, component_scale)
          )

        end

        model.commit_operation

        # Undoes if target missed.
        Sketchup.undo if component.bounds.height == 0

      end

      nil

    end

  end

end
