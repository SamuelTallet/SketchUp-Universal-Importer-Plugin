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

require 'sketchup'
require 'open-uri'

# Universal Importer plugin namespace.
module UniversalImporter

  # Donate helper.
  module Donate

    @@url = 'https://www.paypal.me/SamuelTallet'

    # Fetches URL to donate from GitHub or defaults to PayPal.Me URL.
    def self.fetch_url
      github_url = 'https://raw.githubusercontent.com/SamuelTallet/SketchUp-Universal-Importer-Plugin/master/config/donate.url'
      @@url = open(github_url).read.strip # FIXME: Why it's so slow?
    rescue
      puts "Universal Importer Error: Unable to access #{GITHUB_URL}"
    end

    # URL to donate.
    #
    # @return [String]
    def self.url
      @@url
    end
    
    @@invitation_planned = false

    # Plans an invitation to donate or marks this invitation as no longer planned.
    # 
    # @param [Boolean] planned
    #
    # @raise [ArgumentError]
    def self.invitation_planned=(planned)
      raise ArgumentError, 'Planned must be a Boolean'\
        unless planned == true || planned == false

      @@invitation_planned = planned
    end

    # Is an invitation to donate planned?
    #
    # @return [Boolean]
    def self.invitation_planned?
      @@invitation_planned
    end

    # Invites user to donate.
    def self.invite_user
      answer = UI.messagebox(
        TRANSLATE['Is Universal Importer plugin useful for you? Would you like to support its author with a modest donation?'],
        MB_YESNO
      )
      UI.openURL(@@url) if answer == IDYES
    end

  end

end
