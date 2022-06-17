# Universal Importer extension for SketchUp 2017 or newer.
# Copyright: © 2022 Samuel Tallet <samuel.tallet at gmail dot com>
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

# Universal Importer plugin namespace.
module UniversalImporter

  # Options used during import of 3D model.
  module Options

    # Initializes options with default values.
    @@options = {
      :propose_polygon_reduction? => true,
      :claim_missing_textures? => false
    }

    # Sets "Propose polygon reduction" option.
    # 
    # @param [Boolean] yes_or_no
    #
    # @raise [ArgumentError]
    def self.propose_polygon_reduction=(yes_or_no)
      raise ArgumentError, 'Yes or No must be a Boolean.' unless yes_or_no == true || yes_or_no == false

      @@options[:propose_polygon_reduction?] = yes_or_no
    end

    # Gets "Propose polygon reduction" option.
    #
    # @return [Boolean]
    def self.propose_polygon_reduction?
      @@options[:propose_polygon_reduction?]
    end

    # Sets "Claim missing textures" option.
    # 
    # @param [Boolean] yes_or_no
    #
    # @raise [ArgumentError]
    def self.claim_missing_textures=(yes_or_no)
      raise ArgumentError, 'Yes or No must be a Boolean.' unless yes_or_no == true || yes_or_no == false

      @@options[:claim_missing_textures?] = yes_or_no
    end

    # Gets "Claim missing textures" option.
    #
    # @return [Boolean]
    def self.claim_missing_textures?
      @@options[:claim_missing_textures?]
    end

  end

end
