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

require 'fileutils'

# Universal Importer plugin namespace.
module UniversalImporter

  # Minimal OBJ MTL parser.
  class MTL

    # Parses an OBJ MTL file.
    def initialize(file_path)

      raise ArgumentError, 'File Path parameter must be a String.'\
        unless file_path.is_a?(String)

      file_contents = File.read(file_path)

      @header = ''

      @materials = []

      file_contents.split('newmtl').each do |material_or_header|
  
        line_count = 0
        
        material_or_header.lines.each do |line|

          # XXX Naturally, we ignore comments & empty lines.
          next if line.start_with?('#') || line.strip.empty?

          line_count += 1

        end
        
        if line_count == 0

          @header = material_or_header

        else

          @materials.push('newmtl' + material_or_header)

        end
      
      end

    end

    # If they exist: returns materials without textures.
    #
    # @return [Array<String>]
    def materials_wo_textures

      output = []

      @materials.each do |material|

        material_name = ''

        material_has_texture = false

        material.lines.each do |line|

          if line.start_with?('newmtl')
        
            material_name = line.sub('newmtl', '').strip

          elsif line.start_with?('map_Kd')

            material_has_texture = true

          end
            
        end

        if !material_has_texture

          output.push(material_name)

        end

      end

      output

    end

    # Assigns a texture to a material.
    def set_material_texture(material_name, texture_path)

      new_materials = []

      @materials.each do |material|

        material_matches = false

        material.lines.each do |line|

          if line.start_with?('newmtl')\
            && line.sub('newmtl', '').strip == material_name

            material_matches = true

            break

          end
            
        end

        if material_matches

          material += 'map_Kd ' + texture_path + "\n\n"

        end

        new_materials.push(material)

      end

      @materials = new_materials

    end

    # Returns rebuilt file contents.
    #
    # @return [String]
    def rebuilt_file_contents

      tag = "\n# File modified by Universal Importer plugin for SketchUp. \n\n"

      @header + tag + @materials.join

    end

  end

end
