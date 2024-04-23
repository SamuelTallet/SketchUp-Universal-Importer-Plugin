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

require 'fileutils'

# Universal Importer plugin namespace.
module UniversalImporter

  # Minimal Wavefront Material Template Library (MTL) parser.
  # @see https://wikipedia.org/wiki/Material_Template_Library
  class MTL
    attr_accessor :materials

    # Parses a MTL file.
    #
    # @param [String] file_path Absolute path to a MTL file.
    def initialize(file_path)
      # Generator name.
      @generator = nil
      # Materials names and properties.
      @materials = {}
      # Current material name.
      material_name = nil

      # For each line in the MTL file:
      File.foreach(file_path) do |line|
        # Removes lead/trail spaces of current line to align it with checks below.
        line = line.strip

        # If current line is a comment:
        if line.start_with?("#")
          # We assume the generator name is the first (non-empty) comment.
          @generator = line if @generator.nil? && line =~ /#.+/
          next # Let's search a material.
        end

        # Checks if current line declares a material name or a material property.
        case line
        # New material (name):
        when /^newmtl\s+(.+)/
          material_name = $1
          @materials[material_name] = {}
        # Material diffuse color (r)(g)(b):
        when /^Kd\s+(.+)\s+(.+)\s+(.+)/
          @materials[material_name][:diffuse_color] = [$1.to_f, $2.to_f, $3.to_f]
        # Material diffuse texture (path):
        # Texture statements are not supported, but this should not be an issue...
        when /^map_Kd\s+(.+)/
          @materials[material_name][:diffuse_texture] = $1
        end
      end
    end

    # Rebuilds the MTL file as a string.
    # Unsupported material properties (for example `bump`) go to oblivion.
    #
    # @return [String]
    def to_s
      mtl = ""
      mtl << "#{@generator}\n" if @generator

      @materials.each do |material_name, material|
        mtl << "newmtl #{material_name}\n"
        mtl << "Kd #{material[:diffuse_color].join(" ")}\n" if material[:diffuse_color]
        mtl << "map_Kd #{material[:diffuse_texture]}\n" if material[:diffuse_texture]
      end

      mtl
    end

  end

end
