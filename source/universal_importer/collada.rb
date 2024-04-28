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

  # Misc fixes for the COLLADA (DAE) files imported in SketchUp.
  # @see https://en.wikipedia.org/wiki/COLLADA
  module COLLADA

    # Fixes the materials names of the active SketchUp model following a DAE import.
    # Because SketchUp imports DAE files with generic materials names, e.g. `<auto>1`
    #
    # @param [Hash] materials_name Materials names indexed by texture path or color.
    #
    # @raise [ArgumentError]
    def self.fix_materials_names(materials_names)

      raise ArgumentError, 'materials_names must be a Hash' \
        unless materials_names.is_a?(Hash)

      Sketchup.active_model.materials.each { |material|
        next unless material.name.start_with?('<auto>')

        if material.texture.is_a?(Sketchup::Texture)
          if materials_names.key?(material.texture.filename)
            material.name = materials_names[material.texture.filename]
          end
        elsif material.color.is_a?(Sketchup::Color)
          if materials_names.key?(material.color.to_a)
            material.name = materials_names[material.color.to_a]
          end
        end
      }

    end

  end

end
