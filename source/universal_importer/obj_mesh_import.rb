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

  # Imports an OBJ file as a mesh into SketchUp.
  class ObjMeshImport

    # Initializes an OBJ mesh importer.
    #
    # @param [String] file_path Absolute path to the OBJ file to import.
    # @param [String] component_name Name to give to the component definition.
    # @param [String] operation_name Name of the SketchUp operation.
    def initialize(file_path, component_name, operation_name = TRANSLATE['Import Component'])
      @file_path = file_path
      @component_name = component_name
      @operation_name = operation_name

      @vertices = []
      @faces = []
      @groups = {}
      @current_group_path = nil
      @group_name_counts = {} # Used to ensure unique group names.
    end

    # Imports the OBJ file.
    #
    # @return [Sketchup::ComponentInstance] The component instance added to the model.
    def import
      model = Sketchup.active_model
      model.start_operation(@operation_name, disable_ui=true)

      begin
        # Creates a component definition for this OBJ file.
        component_def = model.definitions.add(@component_name)

        # Processes the OBJ file and creates SketchUp groups based on the OBJ data.
        # These groups are added to the component definition.
        File.open(@file_path, 'r') { |file| process_file(file) }
        create_sketchup_groups_recursive(component_def.entities, @groups)

        # Adds an instance of the component definition to the model, at the origin.
        component = model.active_entities.add_instance(component_def, Geom::Transformation.new)
        model.commit_operation

        component
      rescue StandardError
        model.abort_operation
        # Let the caller report the error, so the whole plugin does it the same way.
        raise
      end
    end

    private

    # Processes the OBJ file, line by line.
    # @param [IO] file The file to process.
    def process_file(file)
      file.each_line do |line|
        # Normalizes whitespace in each line to make further processing reliable.
        line = line.gsub(/\t/, ' ').gsub(/\s+/, ' ').strip

        # Parses only relevant lines. The first char indicates the type of data:
        # v = vertex, f = face, g = group.
        if line =~ /^(v|f|g)\s[^\s]+/
          identifier, *data = line.split(' ')
          
          case identifier
          when 'v'
            # Example: "v 1.0 2.0 3.0"
            process_vertex(data)
          when 'f'
            # Example: "f 1/1/1 2/2/2 3/3/3"
            process_face(data)
          when 'g'
            # Example: "g Parent Group/Child Group"
            process_group_name(data.join(' '))
          end
        end

      end
    end

    # Processes the vertex data.
    # @param [Array<String>] vertex_data The vertex data (x, y, z).
    def process_vertex(vertex_data)
      # Checks if the vertex data contains exactly 3 elements and if each is a number.
      if vertex_data.size != 3 || !vertex_data.all? { |v| v =~ /\A-?\d+(\.\d+)?\z/ }
        warn "Vertex ignored due to incorrect format (#{vertex_data.inspect})."
        return
      end

      # OBJ is unitless, so we convert the vertex data to meters.
      vertex_data.map! { |v| v.to_f.m }

      # Adds the vertex to the vertices array and to the current group, if applicable.
      vertex = Geom::Point3d.new(*vertex_data)
      @vertices << vertex
      add_vertex_to_current_group(vertex) if @current_group_path
    end

    # Processes the face data.
    # @param [Array<String>] face_data The face data (vertex index, etc).
    def process_face(face_data)
      # Checks if the face data has a valid format. See below for details.
      if face_data.size < 3 || !face_data.all? { |f| f =~ /\A\d+(\/\d*)?(\/\d*)?\z/ }
        warn "Face ignored due to incorrect format (#{face_data.inspect})."
        return
      end

      # Adds the faces to the faces array and to the current group, if applicable.
      # The face data is in the format "vertex_index/texture_index/normal_index".
      # Vertex index is mandatory, while texture and normal indexes are optional.
      # OBJ uses 1-based indexes, so we subtract 1 to convert to 0-based indexes.
      face = face_data.map { |f| @vertices[f.split('/')[0].to_i - 1] }
      @faces << face
      add_face_to_current_group(face) if @current_group_path
    end

    # Processes the group name.
    # @param [String] group_name The group name, which may indicate a hierarchy.
    def process_group_name(group_name)
      # Ensures the group name is unique
      # and updates the group hierarchy.
      unique_group_name = ensure_unique_group_name(group_name)
      update_group_hierarchy(unique_group_name)
    end

    # Ensures the group name is unique by appending a numerical suffix if needed.
    # @param [String] group_name The group name.
    # @return [String] An unique group name.
    def ensure_unique_group_name(group_name)
      if @group_name_counts.key?(group_name)
        @group_name_counts[group_name] += 1
        "#{group_name}.#{format('%03d', @group_name_counts[group_name])}"
      else
        @group_name_counts[group_name] = 0
        group_name
      end
    end

    # Updates the group hierarchy by setting the current group path.
    # @param [String] group_name The unique group name.
    def update_group_hierarchy(group_name)
      # A slash char in the group name indicates a hierarchy level.
      # This convention is used by Mayo Conv* when it exports an OBJ file.
      @current_group_path = group_name.split('/')
      create_group_hierarchy(@groups, @current_group_path)
      # (*) And possibly other softwares.
    end

    # Recursively creates the group hierarchy in the @groups hash.
    # @param [Hash] groups The groups hash.
    # @param [Array<String>] path The path to the group.
    def create_group_hierarchy(groups, path)
      if path.size == 1
        groups[path[0]] ||= { vertices: [], faces: [] }
      else
        groups[path[0]] ||= {}
        create_group_hierarchy(groups[path[0]], path[1..-1])
      end
    end

    # Adds a vertex to the current group in the hierarchy.
    # @param [Geom::Point3d] vertex The vertex to add.
    def add_vertex_to_current_group(vertex)
      group = find_group_in_hierarchy(@groups, @current_group_path)
      group[:vertices].push(vertex) if group
    end

    # Adds a face to the current group in the hierarchy.
    # @param [Array<Geom::Point3d>] face The face to add.
    def add_face_to_current_group(face)
      group = find_group_in_hierarchy(@groups, @current_group_path)
      group[:faces].push(face) if group
    end

    # Finds a group specified by the path in the hierarchy.
    # @param [Hash] groups The groups hash.
    # @param [Array<String>] path The path to the group.
    # @return [Hash, nil] The group data or nil if not found.
    def find_group_in_hierarchy(groups, path)
      path.reduce(groups) { |current, name| current.is_a?(Hash) ? current[name] : nil }
    end

    # Recursively creates SketchUp groups based on the hierarchy.
    # @param [Sketchup::Entities] parent_entities The parent entities to add the groups to.
    # @param [Hash] groups The groups data.
    def create_sketchup_groups_recursive(parent_entities, groups)
      groups.each do |name, data|
        # Creates a new group and sets its name.
        group = parent_entities.add_group
        group.name = name

        if data.is_a?(Hash) && data.key?(:vertices) && data.key?(:faces)
          # Creates a polygon mesh from the vertices and faces.
          pm = Geom::PolygonMesh.new
          data[:vertices].each { |vertex| pm.add_point(vertex) }
          data[:faces].each { |face| pm.add_polygon(face) }

          # Adds the mesh to the group.
          group.entities.add_faces_from_mesh(pm)
        elsif data.is_a?(Hash)
          # Recursively creates child groups.
          create_sketchup_groups_recursive(group.entities, data)
        end
      end
    end
  end
end
