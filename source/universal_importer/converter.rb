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
require 'fileutils'

# Universal Importer plugin namespace.
module UniversalImporter

  # 3D model converter.
  class Converter

    # Absolute path to Assimp executable.
    #
    # @see https://github.com/assimp/assimp
    ASSIMP_EXE = File.join(__dir__, 'Assimp', 'assimp.exe').freeze

    # Absolute path to Universal Importer program data directory.
    PROGRAMDATA_DIR = File.join(ENV['PROGRAMDATA'], 'Universal Importer').freeze

    # Converts a 3D model.
    def initialize

      begin

        return unless import_from_any_format

        import_texture_atlas

        copy_to_prog_data_dir

        export_to_obj_format

        fix_atlas_in_obj_export

        export_to_dae_format

        fix_unit_in_dae_export

        import_from_dae_format
        
      rescue StandardError => exception

        puts 'Error: ' + exception.message
        puts exception.backtrace
        
      end

    end

    # Imports "any" 3D model.
    #
    # @return [Boolean]
    def import_from_any_format

      @import_file_path = UI.openpanel(

        TRANSLATE['Select a 3D Model'], nil, TRANSLATE['3D Models'] +
        '|*.3d;*.3ds;*.3mf;*.ac;*.ac3d;*.acc;*.amf;*.ase;*.ask;' +
        '*.assbin;*.b3d;*.blend;*.bvh;*.cob;*.csm;*.dae;*.dxf;' +
        '*.enff;*.fbx;*.glb;*.gltf;*.hmp;*.ifc;*.ifczip;*.irr;' +
        '*.irrmesh;*.lwo;*.lws;*.lxo;*.md2;*.md3;*.md5anim;' +
        '*.md5camera;*.md5mesh;*.mdc;*.mdl;*.mesh;*.mesh.xml;' +
        '*.mot;*.ms3d;*.ndo;*.nff;*.obj;*.off;*.ogex;*.pk3;' +
        '*.ply;*.pmx;*.prj;*.q3o;*.q3s;*.raw;*.scn;*.sib;*.smd;' +
        '*.stl;*.stp;*.ter;*.uc;*.vta;*.x;*.x3d;*.x3db;*.xgl;' +
        '*.xml;*.zae;*.zgl;||'

      )

      !@import_file_path.nil?

    end

    # Imports optional texture atlas of 3D model.
    #
    # @return [nil, String]
    def import_texture_atlas

      @import_texture_atlas_file_path = UI.openpanel(

        TRANSLATE['Select a Texture Atlas (Optional)'], nil,
        TRANSLATE['Images'] + '|*.jpg;*.png;*.bmp;||'

      )

    end

    # Copies 3D model and texture atlas to Universal Importer program data dir.
    #
    # @return [nil]
    def copy_to_prog_data_dir

      FileUtils.mkdir_p(PROGRAMDATA_DIR) unless File.exist?(PROGRAMDATA_DIR)

      FileUtils.remove_dir(File.join(PROGRAMDATA_DIR, 'tmp'))\
        if File.exist?(File.join(PROGRAMDATA_DIR, 'tmp'))

      FileUtils.copy_entry(
        File.dirname(@import_file_path), # source
        File.join(PROGRAMDATA_DIR, 'tmp') # destination
      )

      if !@import_texture_atlas_file_path.nil?

        FileUtils.cp(
          @import_texture_atlas_file_path,
          File.join(PROGRAMDATA_DIR, 'tmp')
        )

      end

      temp_import_file_path = File.join(
        PROGRAMDATA_DIR,
        'tmp',
        File.basename(@import_file_path)
      )

      @import_file_path = temp_import_file_path

      nil

    end

    # Exports 3D model to OBJ format.
    #
    # @return [nil, Boolean]
    def export_to_obj_format

      @obj_export_file_path = @import_file_path + '.obj'

      system(
        '"' + ASSIMP_EXE + '" export "' + 
        @import_file_path + '" "' + @obj_export_file_path + '"'
      )

    end

    # Fixes texture atlas in OBJ export.
    #
    # @return [nil]
    def fix_atlas_in_obj_export

      return if @import_texture_atlas_file_path.nil?

      obj_mtl_export_file_path = @import_file_path + '.mtl'

      obj_mtl_export = File.read(obj_mtl_export_file_path)

      obj_mtl_export += "\n"

      obj_mtl_export += 'map_Kd '
      obj_mtl_export += File.basename(@import_texture_atlas_file_path)

      File.write(obj_mtl_export_file_path, obj_mtl_export)

      nil

    end

    # Exports 3D model to DAE format.
    #
    # @return [nil, Boolean]
    def export_to_dae_format

      @dae_export_file_path = @import_file_path + '.dae'

      system(
        '"' + ASSIMP_EXE + '" export "' + 
        @obj_export_file_path + '" "' + @dae_export_file_path + '" -tri'
      )

    end

    # Fixes unit in DAE export.
    #
    # @return [nil]
    def fix_unit_in_dae_export

      dae_export = File.read(@dae_export_file_path)

      dae_export.sub!('meter="1"', 'meter="0.01"')

      File.write(@dae_export_file_path, dae_export)

      nil

    end

    # Imports 3D model from DAE format.
    #
    # @return [Boolean]
    def import_from_dae_format

      Sketchup.active_model.import(@dae_export_file_path)

    end

  end

end
