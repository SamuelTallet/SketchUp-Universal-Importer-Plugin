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

require 'sketchup'
require 'extensions'

raise 'Universal Importer plugin requires at least SketchUp 2017.'\
  unless Sketchup.version.to_i >= 17

# Universal Importer plugin namespace.
module UniversalImporter

  VERSION = '1.2.1'

  # Load translation if it's available for current locale.
  TRANSLATE = LanguageHandler.new('uir.translation')
  # See: "universal_importer/Resources/#{Sketchup.get_locale}/uir.translation"

  PLUGIN_NAME = TRANSLATE['Universal Importer']

  # Registers extension.

  extension = SketchupExtension.new(PLUGIN_NAME, 'universal_importer/load.rb')

  extension.version     = VERSION
  extension.creator     = 'Samuel Tallet'
  extension.copyright   = "© 2023 #{extension.creator}"

  features = [
    TRANSLATE['Import 3D models in SketchUp. 50+ formats are supported.'],
    TRANSLATE['Reduce polygon count on the fly.']
  ]

  extension.description = features.join(' ')

  Sketchup.register_extension(extension, load_at_start=true)

end
