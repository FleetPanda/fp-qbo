# frozen_string_literal: true

module FpQbo
  module Resources
    class Customer < Base
      ENTITY_NAME = "Customer"

      # QBO requires at least DisplayName OR one of: GivenName, MiddleName, FamilyName, FullyQualifiedName, CompanyName, PrintOnCheckName
      REQUIRED_FIELDS = %w[DisplayName].freeze

      # All optional fields supported by QBO Customer API
      OPTIONAL_FIELDS = %w[
        Title GivenName MiddleName FamilyName Suffix CompanyName
        PrintOnCheckName Active PrimaryPhone AlternatePhone Mobile Fax
        PrimaryEmailAddr WebAddr DefaultTaxCodeRef PreferredDeliveryMethod
        ResaleNum Taxable BillAddr ShipAddr Notes Job BillWithParent
        ParentRef Level SalesTermRef PaymentMethodRef Balance OpenBalanceDate
        BalanceWithJobs CurrencyRef
      ].freeze

      def entity_name
        ENTITY_NAME
      end

      def required_fields
        REQUIRED_FIELDS
      end

      # Create customer with validation and field mapping
      def create(attributes)
        mapped_attributes = map_customer_attributes(attributes)
        super(mapped_attributes)
      end

      # Update customer
      def update(id, attributes)
        mapped_attributes = map_customer_attributes(attributes)
        super(id, mapped_attributes)
      end

      # Find customer by display name
      def find_by_name(name)
        query("SELECT * FROM #{entity_name} WHERE DisplayName = '#{escape_sql(name)}'")
      end

      # Find customer by email
      def find_by_email(email)
        query("SELECT * FROM #{entity_name} WHERE PrimaryEmailAddr = '#{escape_sql(email)}'")
      end

      # Get active customers only
      def active_customers(limit: 100)
        list(where: "Active = true", limit: limit)
      end

      # Search customers by partial name match
      def search(term, limit: 100)
        query("SELECT * FROM #{entity_name} WHERE DisplayName LIKE '%#{escape_sql(term)}%' MAXRESULTS #{limit}")
      end

      private

      # Map incoming attributes to QBO Customer format
      def map_customer_attributes(attributes)
        payload = {}

        # Basic Information
        if attributes[:display_name] || attributes["DisplayName"]
          payload["DisplayName"] =
            attributes[:display_name] || attributes["DisplayName"]
        end
        payload["Title"] = attributes[:title] || attributes["Title"] if attributes[:title] || attributes["Title"]
        if attributes[:given_name] || attributes[:first_name] || attributes["GivenName"]
          payload["GivenName"] =
            attributes[:given_name] || attributes[:first_name] || attributes["GivenName"]
        end
        if attributes[:middle_name] || attributes["MiddleName"]
          payload["MiddleName"] =
            attributes[:middle_name] || attributes["MiddleName"]
        end
        if attributes[:family_name] || attributes[:last_name] || attributes["FamilyName"]
          payload["FamilyName"] =
            attributes[:family_name] || attributes[:last_name] || attributes["FamilyName"]
        end
        payload["Suffix"] = attributes[:suffix] || attributes["Suffix"] if attributes[:suffix] || attributes["Suffix"]
        if attributes[:company_name] || attributes["CompanyName"]
          payload["CompanyName"] =
            attributes[:company_name] || attributes["CompanyName"]
        end
        if attributes[:print_on_check_name] || attributes["PrintOnCheckName"]
          payload["PrintOnCheckName"] =
            attributes[:print_on_check_name] || attributes["PrintOnCheckName"]
        end

        # Status
        payload["Active"] = attributes[:active].nil? || attributes[:active] if attributes.key?(:active)
        payload["Active"] = attributes["Active"] if attributes.key?("Active")

        # Contact Information
        payload["PrimaryPhone"] =
          map_phone(attributes[:primary_phone] || attributes[:phone] || attributes["PrimaryPhone"])
        payload["AlternatePhone"] = map_phone(attributes[:alternate_phone] || attributes["AlternatePhone"])
        payload["Mobile"] = map_phone(attributes[:mobile] || attributes["Mobile"])
        payload["Fax"] = map_phone(attributes[:fax] || attributes["Fax"])

        # Email and Web
        payload["PrimaryEmailAddr"] =
          map_email(attributes[:primary_email] || attributes[:email] || attributes["PrimaryEmailAddr"])
        payload["WebAddr"] = map_web_address(attributes[:website] || attributes[:web_addr] || attributes["WebAddr"])

        # Addresses
        payload["BillAddr"] =
          map_address(attributes[:billing_address] || attributes[:bill_addr] || attributes["BillAddr"])
        payload["ShipAddr"] =
          map_address(attributes[:shipping_address] || attributes[:ship_addr] || attributes["ShipAddr"])

        # Financial Information
        payload["CurrencyRef"] = map_reference(attributes[:currency] || attributes["CurrencyRef"], "USD")
        payload["PaymentMethodRef"] = map_reference(attributes[:payment_method] || attributes["PaymentMethodRef"])
        payload["SalesTermRef"] =
          map_reference(attributes[:sales_term] || attributes[:terms] || attributes["SalesTermRef"])
        payload["DefaultTaxCodeRef"] = map_reference(attributes[:tax_code] || attributes["DefaultTaxCodeRef"])

        # Tax Information
        payload["Taxable"] = attributes[:taxable] if attributes.key?(:taxable)
        payload["Taxable"] = attributes["Taxable"] if attributes.key?("Taxable")
        if attributes[:resale_number] || attributes["ResaleNum"]
          payload["ResaleNum"] =
            attributes[:resale_number] || attributes["ResaleNum"]
        end

        # Additional Fields
        payload["Notes"] = attributes[:notes] || attributes["Notes"] if attributes[:notes] || attributes["Notes"]
        if attributes[:is_job] || attributes[:job] || attributes["Job"]
          payload["Job"] =
            attributes[:is_job] || attributes[:job] || attributes["Job"]
        end
        if attributes[:bill_with_parent] || attributes["BillWithParent"]
          payload["BillWithParent"] =
            attributes[:bill_with_parent] || attributes["BillWithParent"]
        end
        payload["ParentRef"] = map_reference(attributes[:parent] || attributes[:parent_ref] || attributes["ParentRef"])
        payload["Level"] = attributes[:level] || attributes["Level"] if attributes[:level] || attributes["Level"]
        if attributes[:preferred_delivery_method] || attributes["PreferredDeliveryMethod"]
          payload["PreferredDeliveryMethod"] =
            attributes[:preferred_delivery_method] || attributes["PreferredDeliveryMethod"]
        end

        # Balance (usually for opening balance)
        if attributes[:opening_balance_date] || attributes["OpenBalanceDate"]
          payload["OpenBalanceDate"] =
            attributes[:opening_balance_date] || attributes["OpenBalanceDate"]
        end
        if attributes[:balance] || attributes["Balance"]
          payload["Balance"] =
            attributes[:balance] || attributes["Balance"]
        end

        # Remove nil values
        payload.compact
      end

      # Map phone number to QBO format
      def map_phone(phone_data)
        return nil if phone_data.nil?

        if phone_data.is_a?(String)
          { "FreeFormNumber" => phone_data }
        elsif phone_data.is_a?(Hash)
          phone_data["FreeFormNumber"] ? phone_data : { "FreeFormNumber" => phone_data[:number] || phone_data[:free_form_number] }
        end
      end

      # Map email to QBO format
      def map_email(email_data)
        return nil if email_data.nil?

        if email_data.is_a?(String)
          { "Address" => email_data }
        elsif email_data.is_a?(Hash)
          email_data["Address"] ? email_data : { "Address" => email_data[:address] || email_data[:email] }
        end
      end

      # Map web address to QBO format
      def map_web_address(web_data)
        return nil if web_data.nil?

        if web_data.is_a?(String)
          { "URI" => web_data }
        elsif web_data.is_a?(Hash)
          web_data["URI"] ? web_data : { "URI" => web_data[:uri] || web_data[:url] }
        end
      end

      # Map address to QBO format
      def map_address(address_data)
        return nil if address_data.nil?
        return address_data if address_data["Line1"] || address_data["City"] # Already in QBO format

        {
          "Line1" => address_data[:line1] || address_data[:street] || address_data[:address1],
          "Line2" => address_data[:line2] || address_data[:address2],
          "Line3" => address_data[:line3],
          "City" => address_data[:city],
          "CountrySubDivisionCode" => address_data[:state] || address_data[:country_sub_division_code],
          "PostalCode" => address_data[:postal_code] || address_data[:zip] || address_data[:zip_code],
          "Country" => address_data[:country],
          "Lat" => address_data[:latitude] || address_data[:lat],
          "Long" => address_data[:longitude] || address_data[:long]
        }.compact
      end

      # Map reference to QBO format
      def map_reference(ref_data, default_value = nil)
        return nil if ref_data.nil? && default_value.nil?
        return { "value" => default_value } if ref_data.nil?

        if ref_data.is_a?(String) || ref_data.is_a?(Integer)
          { "value" => ref_data.to_s }
        elsif ref_data.is_a?(Hash)
          ref_data["value"] ? ref_data : { "value" => ref_data[:value] || ref_data[:id] }
        end
      end

      # Escape SQL for queries
      def escape_sql(value)
        value.to_s.gsub("'", "\\'")
      end

      # Override build_payload to ensure proper structure
      def build_payload(attributes)
        # Ensure DisplayName is present
        unless attributes["DisplayName"]
          # Try to construct from name parts
          if attributes["GivenName"] || attributes["FamilyName"]
            name_parts = [
              attributes["GivenName"],
              attributes["MiddleName"],
              attributes["FamilyName"]
            ].compact
            attributes["DisplayName"] = name_parts.join(" ") unless name_parts.empty?
          elsif attributes["CompanyName"]
            attributes["DisplayName"] = attributes["CompanyName"]
          end
        end

        attributes
      end
    end
  end
end
