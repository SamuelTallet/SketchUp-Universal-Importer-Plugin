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
require 'universal_importer/mtl'

# Universal Importer plugin namespace.
module UniversalImporter

  # Imports an OBJ file as a mesh into SketchUp, colored with the diffuse colors
  # of its companion MTL file, if any.
  class ObjMeshImport

    # Smoothing flags applied to the faces created from a polygon mesh.
    SMOOTH_FLAGS = Geom::PolygonMesh::AUTO_SOFTEN | Geom::PolygonMesh::SMOOTH_SOFT_EDGES

    # Maximum number of bodies a lone group is split into. Above that count, the mesh is a
    # tessellated model rather than a multi-body part.
    MAX_BODIES = 100

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
      @groups = {}
      @current_group_path = nil
      @group_name_counts = {} # Used to ensure unique group names.
      @materials = {} # SketchUp materials indexed by OBJ material name.
      @current_material_name = nil
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
        split_lone_group_into_bodies
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

        # Parses only relevant lines. The first word indicates the type of data: v = vertex,
        # f = face, g = group, mtllib = material library, usemtl = material to apply.
        next unless line =~ /^(v|f|g|mtllib|usemtl)\s[^\s]+/

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
        when 'mtllib'
          # Example: "mtllib model.mtl"
          load_materials(data.join(' '))
        when 'usemtl'
          # Example: "usemtl mat_1"
          @current_material_name = data.join(' ')
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

      # Adds the vertex to the vertices array.
      @vertices << Geom::Point3d.new(*vertex_data)
    end

    # Processes the face data.
    # @param [Array<String>] face_data The face data (vertex index, etc).
    def process_face(face_data)
      # Checks if the face data has a valid format. See below for details.
      if face_data.size < 3 || !face_data.all? { |f| f =~ /\A\d+(\/\d*)?(\/\d*)?\z/ }
        warn "Face ignored due to incorrect format (#{face_data.inspect})."
        return
      end

      # Adds the face to the current group, if applicable.
      # The face data is in the format "vertex_index/texture_index/normal_index".
      # Vertex index is mandatory, while texture and normal indexes are optional.
      # OBJ uses 1-based indexes, so we subtract 1 to convert to 0-based indexes.
      face = face_data.map { |f| @vertices[f.split('/')[0].to_i - 1] }
      add_face_to_current_group(face) if @current_group_path
    end

    # Loads, as SketchUp materials, the colors defined in a MTL file.
    # @param [String] mtl_filename Filename of the MTL file, relative to the OBJ file.
    def load_materials(mtl_filename)
      mtl_file_path = File.join(File.dirname(@file_path), mtl_filename)

      unless File.exist?(mtl_file_path)
        warn "Materials ignored due to missing MTL file (#{mtl_filename})."
        return
      end

      MTL.new(mtl_file_path).materials.each do |material_name, material_properties|
        diffuse_color = material_properties[:diffuse_color]
        next unless diffuse_color

        material = Sketchup.active_model.materials.add(material_name)
        # MTL colors are floats between 0 and 1, SketchUp colors are integers between 0 and 255.
        material.color = Sketchup::Color.new(*diffuse_color.map { |value| (value * 255).round })
        @materials[material_name] = material
      end
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
        # Faces of a group are indexed by material name, as a mesh has only one material.
        groups[path[0]] ||= { faces: {} }
      else
        groups[path[0]] ||= {}
        create_group_hierarchy(groups[path[0]], path[1..-1])
      end
    end

    # Adds a face, with its current material, to the current group in the hierarchy.
    # @param [Array<Geom::Point3d>] face The face to add.
    def add_face_to_current_group(face)
      group = find_group_in_hierarchy(@groups, @current_group_path)
      return unless group

      (group[:faces][@current_material_name] ||= []).push(face)
    end

    # Finds a group specified by the path in the hierarchy.
    # @param [Hash] groups The groups hash.
    # @param [Array<String>] path The path to the group.
    # @return [Hash, nil] The group data or nil if not found.
    def find_group_in_hierarchy(groups, path)
      path.reduce(groups) { |current, name| current.is_a?(Hash) ? current[name] : nil }
    end

    # Splits the lone group of the hierarchy into one sub-group per body.
    #
    # A CAD model without any assembly structure, such as a multi-body part, is exported by
    # Mayo Conv as a lone OBJ group. Its bodies being disjoint meshes, they can be told apart.
    def split_lone_group_into_bodies
      return unless @groups.size == 1

      group_name, group_data = @groups.first
      # A group holding other groups is a hierarchy level, not a mesh.
      return unless group_data.key?(:faces)

      faces_per_body = split_faces_into_bodies(group_data[:faces])
      # Keeps the group as it is when its mesh is made of a single connected piece.
      return if faces_per_body.size < 2

      if faces_per_body.size > MAX_BODIES
        warn "Bodies not grouped: #{faces_per_body.size} of them, more than the #{MAX_BODIES} allowed"
        return
      end

      # The bodies are left unnamed: their CAD names are lost on export. They are keyed by index.
      sub_groups = {}
      faces_per_body.each_with_index do |body_faces, body_index|
        sub_groups[body_index] = { faces: body_faces }
      end

      @groups[group_name] = sub_groups
    end

    # Splits faces into connected components: the bodies of the mesh.
    #
    # @param [Hash] faces_by_material The faces of a group, indexed by material name.
    #
    # @return [Array<Hash>] The faces of each body, indexed by material name.
    def split_faces_into_bodies(faces_by_material)
      # Canonical vertex index of each position. Mayo Conv duplicates the vertices shared by two
      # faces of a same CAD solid, with the very same decimals: comparing exactly is enough.
      indexes_by_position = {}
      # Union-Find parent of each canonical vertex index.
      parents = []
      # Each face, with its material name and its canonical vertex indexes.
      indexed_faces = []

      faces_by_material.each do |material_name, faces|
        faces.each do |face|

          vertex_indexes = face.map do |point|
            position = point.to_a.map { |coordinate| coordinate.to_f }

            indexes_by_position[position] ||= begin
              parents.push(parents.size)
              parents.size - 1
            end
          end

          # Two faces sharing at least one vertex belong to the same body.
          vertex_indexes.drop(1).each { |vertex_index| unite(parents, vertex_indexes[0], vertex_index) }

          indexed_faces.push([material_name, face, vertex_indexes])

        end
      end

      faces_by_body = {}
      indexed_faces.each do |material_name, face, vertex_indexes|
        body = (faces_by_body[find_root(parents, vertex_indexes[0])] ||= {})
        (body[material_name] ||= []).push(face)
      end

      faces_by_body.values
    end

    # Finds the root of a vertex in the Union-Find structure, compressing the path leading to it.
    #
    # @return [Integer] The root of the vertex: the identifier of the body it belongs to.
    def find_root(parents, vertex_index)
      root = vertex_index
      root = parents[root] while parents[root] != root

      # Path compression: hooks each visited vertex directly to the root.
      while parents[vertex_index] != root
        parents[vertex_index], vertex_index = root, parents[vertex_index]
      end

      root
    end

    # Unites, in the Union-Find structure, the bodies two vertices belong to.
    def unite(parents, first_vertex_index, second_vertex_index)
      first_root = find_root(parents, first_vertex_index)
      second_root = find_root(parents, second_vertex_index)

      parents[first_root] = second_root if first_root != second_root
    end

    # Recursively creates SketchUp groups based on the hierarchy.
    # @param [Sketchup::Entities] parent_entities The parent entities to add the groups to.
    # @param [Hash] groups The groups data.
    def create_sketchup_groups_recursive(parent_entities, groups)
      groups.each do |name, data|
        group = parent_entities.add_group
        # An unnamed body is keyed by its index, so only a String is a name to set.
        group.name = name if name.is_a?(String)

        if data.key?(:faces)
          # Creates a polygon mesh, then faces, per material.
          data[:faces].each do |material_name, faces|
            pm = Geom::PolygonMesh.new
            faces.each { |face| pm.add_polygon(face) }

            material = @materials[material_name]
            # The material is applied on both sides to color faces whatever their orientation.
            group.entities.add_faces_from_mesh(pm, SMOOTH_FLAGS, material, material)
          end
        else
          # Recursively creates child groups.
          create_sketchup_groups_recursive(group.entities, data)
        end
      end
    end
  end
end
