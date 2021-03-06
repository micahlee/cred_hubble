require 'cred_hubble/resources/credential'

module CredHubble
  module Resources
    class ValueCredential < Credential
      attribute :value, String

      def type
        Credential::VALUE_TYPE
      end
    end
  end
end
