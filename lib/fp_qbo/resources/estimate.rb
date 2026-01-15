# frozen_string_literal: true

module FpQbo
  module Resources
    class Estimate < Base
      ENTITY_NAME = "Estimate"

      # Required fields for QBO Estimate
      # At minimum: CustomerRef and at least one Line item with Amount
      REQUIRED_FIELDS = %w[CustomerRef Line].freeze

      def entity_name
        ENTITY_NAME
      end

      def required_fields
        REQUIRED_FIELDS
      end

      # Create estimate with validation and field mapping
      def create(attributes)
        mapped_attributes = map_estimate_attributes(attributes)
        validate_line_items!(mapped_attributes)
        super(mapped_attributes)
      end

      # Update estimate
      def update(id, attributes)
        mapped_attributes = map_estimate_attributes(attributes)
        validate_line_items!(mapped_attributes) if mapped_attributes[:Line] || mapped_attributes["Line"]
        super(id, mapped_attributes)
      end

      # Find estimates by customer
      def find_by_customer(customer_id)
        query("SELECT * FROM #{entity_name} WHERE CustomerRef = '#{escape_sql(customer_id)}'")
      end

      # Find estimates by status
      def find_by_status(status)
        # Status can be: Accepted, Closed, Pending, Rejected
        query("SELECT * FROM #{entity_name} WHERE TxnStatus = '#{escape_sql(status)}'")
      end

      # Get pending estimates
      def pending_estimates(limit: 100)
        list(where: "TxnStatus = 'Pending'", limit: limit, order_by: "TxnDate DESC")
      end

      # Get accepted estimates
      def accepted_estimates(limit: 100)
        list(where: "TxnStatus = 'Accepted'", limit: limit, order_by: "TxnDate DESC")
      end

      # Convert estimate to invoice (returns estimate data for invoice creation)
      def prepare_for_invoice(estimate_id)
        response = find(estimate_id)
        return response unless response.success?

        estimate = response.entity

        # Return data formatted for invoice creation
        {
          customer_ref: estimate["CustomerRef"],
          line: estimate["Line"],
          billing_address: estimate["BillAddr"],
          shipping_address: estimate["ShipAddr"],
          customer_memo: estimate["CustomerMemo"],
          sales_term_ref: estimate["SalesTermRef"],
          due_date: calculate_due_date(estimate["TxnDate"], estimate["SalesTermRef"]),
          txn_date: Date.today.to_s,
          private_note: "Created from Estimate ##{estimate["DocNumber"]}"
        }
      end

      # Send estimate by email
      def send_email(estimate_id, email_address)
        response = client.post(
          endpoint: "#{entity_name.downcase}/#{estimate_id}/send",
          payload: {},
          params: { sendTo: email_address }
        )

        handle_response(response, :send_email)
      end

      private

      # Map incoming attributes to QBO Estimate format
      def map_estimate_attributes(attributes)
        payload = {}

        # Customer Reference (REQUIRED)
        payload["CustomerRef"] = map_reference(
          attributes[:customer_ref] ||
          attributes[:customer] ||
          attributes["CustomerRef"]
        )

        # Line Items (REQUIRED) - at least one line
        payload["Line"] = map_line_items(
          attributes[:line_items] ||
          attributes[:lines] ||
          attributes[:Line] ||
          attributes["Line"]
        )

        # Document Information
        payload["DocNumber"] = attributes[:doc_number] || attributes["DocNumber"]
        payload["TxnDate"] =
          attributes[:txn_date] || attributes[:transaction_date] || attributes["TxnDate"] || Date.today.to_s
        payload["ExpirationDate"] = attributes[:expiration_date] || attributes["ExpirationDate"]

        # Status (Accepted, Closed, Pending, Rejected)
        payload["TxnStatus"] = attributes[:txn_status] || attributes[:status] || attributes["TxnStatus"]

        # Addresses
        payload["BillAddr"] =
          map_address(attributes[:billing_address] || attributes[:bill_addr] || attributes["BillAddr"])
        payload["ShipAddr"] =
          map_address(attributes[:shipping_address] || attributes[:ship_addr] || attributes["ShipAddr"])
        payload["ShipFromAddr"] = map_address(attributes[:ship_from_address] || attributes["ShipFromAddr"])

        # Shipping Information
        payload["ShipMethodRef"] = map_reference(attributes[:ship_method] || attributes["ShipMethodRef"])
        payload["ShipDate"] = attributes[:ship_date] || attributes["ShipDate"]
        payload["TrackingNum"] = attributes[:tracking_number] || attributes["TrackingNum"]

        # Financial Information
        payload["SalesTermRef"] =
          map_reference(attributes[:sales_term] || attributes[:terms] || attributes["SalesTermRef"])
        payload["DueDate"] = attributes[:due_date] || attributes["DueDate"]
        payload["CurrencyRef"] = map_reference(attributes[:currency] || attributes["CurrencyRef"], "USD")
        payload["ExchangeRate"] = attributes[:exchange_rate] || attributes["ExchangeRate"]

        # Tax Information
        payload["TxnTaxDetail"] = map_tax_detail(attributes[:tax_detail] || attributes["TxnTaxDetail"])
        payload["GlobalTaxCalculation"] = attributes[:global_tax_calculation] || attributes["GlobalTaxCalculation"]

        # Memo and Notes
        payload["CustomerMemo"] =
          map_memo(attributes[:customer_memo] || attributes[:memo] || attributes["CustomerMemo"])
        payload["PrivateNote"] = attributes[:private_note] || attributes[:notes] || attributes["PrivateNote"]

        # References
        payload["ClassRef"] = map_reference(attributes[:class_ref] || attributes[:class] || attributes["ClassRef"])
        payload["DepartmentRef"] = map_reference(attributes[:department] || attributes["DepartmentRef"])

        # Email and Delivery
        payload["BillEmail"] = map_email(attributes[:bill_email] || attributes["BillEmail"])
        payload["EmailStatus"] = attributes[:email_status] || attributes["EmailStatus"]
        payload["DeliveryInfo"] = map_delivery_info(attributes[:delivery_info] || attributes["DeliveryInfo"])

        # Totals (usually calculated by QBO, but can be set)
        payload["TotalAmt"] = attributes[:total_amount] || attributes["TotalAmt"]
        payload["HomeTotalAmt"] = attributes[:home_total_amount] || attributes["HomeTotalAmt"]

        # Custom Fields
        payload["CustomField"] = map_custom_fields(attributes[:custom_fields] || attributes["CustomField"])

        # Accepted Status Information (read-only, but can be included)
        payload["AcceptedBy"] = attributes[:accepted_by] || attributes["AcceptedBy"]
        payload["AcceptedDate"] = attributes[:accepted_date] || attributes["AcceptedDate"]

        # Apply tax (after discount, yes/no)
        payload["ApplyTaxAfterDiscount"] = attributes[:apply_tax_after_discount] || attributes["ApplyTaxAfterDiscount"]

        # Print Status
        payload["PrintStatus"] = attributes[:print_status] || attributes["PrintStatus"]

        # Remove nil values
        payload.compact
      end

      # Map line items to QBO format
      def map_line_items(items)
        return [] unless items

        items = [items] unless items.is_a?(Array)

        items.map.with_index do |item, index|
          line = {}

          # Line identification
          line["Id"] = item[:id] || item["Id"] || index.to_s
          line["LineNum"] = item[:line_num] || item[:line_number] || item["LineNum"] || (index + 1).to_s
          line["Description"] = item[:description] || item["Description"]

          # Amount (REQUIRED for each line)
          line["Amount"] = item[:amount] || item["Amount"]

          # Detail Type (REQUIRED) - SalesItemLineDetail, GroupLineDetail, DescriptionOnlyLineDetail, DiscountLineDetail, SubTotalLineDetail
          line["DetailType"] = item[:detail_type] || item["DetailType"] || "SalesItemLineDetail"

          # Sales Item Line Detail (most common for products/services)
          if line["DetailType"] == "SalesItemLineDetail"
            line["SalesItemLineDetail"] = map_sales_item_detail(
              item[:sales_item_detail] ||
              item[:item_detail] ||
              item["SalesItemLineDetail"] ||
              item
            )
          end

          # Group Line Detail (for grouped items)
          if line["DetailType"] == "GroupLineDetail"
            line["GroupLineDetail"] = map_group_line_detail(
              item[:group_line_detail] ||
              item["GroupLineDetail"]
            )
          end

          # Discount Line Detail
          if line["DetailType"] == "DiscountLineDetail"
            line["DiscountLineDetail"] = map_discount_line_detail(
              item[:discount_line_detail] ||
              item["DiscountLineDetail"]
            )
          end

          # Custom fields for line
          line["CustomField"] = map_custom_fields(item[:custom_fields] || item["CustomField"])

          line.compact
        end
      end

      # Map sales item detail
      def map_sales_item_detail(detail)
        return nil unless detail

        sales_detail = {}

        # Item Reference (REQUIRED for SalesItemLineDetail)
        sales_detail["ItemRef"] = map_reference(
          detail[:item_ref] ||
          detail[:item] ||
          detail[:item_id] ||
          detail["ItemRef"]
        )

        # Quantity and Pricing
        sales_detail["Qty"] = detail[:qty] || detail[:quantity] || detail["Qty"]
        sales_detail["UnitPrice"] = detail[:unit_price] || detail[:price] || detail["UnitPrice"]

        # Tax
        sales_detail["TaxCodeRef"] = map_reference(detail[:tax_code] || detail["TaxCodeRef"])
        sales_detail["TaxInclusiveAmt"] = detail[:tax_inclusive_amount] || detail["TaxInclusiveAmt"]

        # Markup
        sales_detail["MarkupInfo"] = map_markup_info(detail[:markup_info] || detail["MarkupInfo"])

        # Service Date
        sales_detail["ServiceDate"] = detail[:service_date] || detail["ServiceDate"]

        # Discount
        sales_detail["DiscountRate"] = detail[:discount_rate] || detail["DiscountRate"]
        sales_detail["DiscountAmt"] = detail[:discount_amount] || detail["DiscountAmt"]

        # Class
        sales_detail["ClassRef"] = map_reference(detail[:class] || detail["ClassRef"])

        sales_detail.compact
      end

      # Map group line detail
      def map_group_line_detail(detail)
        return nil unless detail

        {
          "GroupItemRef" => map_reference(detail[:group_item] || detail["GroupItemRef"]),
          "Quantity" => detail[:quantity] || detail["Quantity"]
        }.compact
      end

      # Map discount line detail
      def map_discount_line_detail(detail)
        return nil unless detail

        discount = {}
        discount["PercentBased"] = detail[:percent_based] || detail["PercentBased"]
        discount["DiscountPercent"] = detail[:discount_percent] || detail["DiscountPercent"]
        discount["DiscountAccountRef"] = map_reference(detail[:discount_account] || detail["DiscountAccountRef"])
        discount.compact
      end

      # Map tax detail
      def map_tax_detail(detail)
        return nil unless detail

        tax_detail = {}
        tax_detail["TxnTaxCodeRef"] = map_reference(detail[:tax_code] || detail["TxnTaxCodeRef"])
        tax_detail["TotalTax"] = detail[:total_tax] || detail["TotalTax"]

        if detail[:tax_line] || detail["TaxLine"]
          tax_detail["TaxLine"] = map_tax_lines(detail[:tax_line] || detail["TaxLine"])
        end

        tax_detail.compact
      end

      # Map tax lines
      def map_tax_lines(lines)
        return [] unless lines

        lines = [lines] unless lines.is_a?(Array)

        lines.map do |line|
          {
            "Amount" => line[:amount] || line["Amount"],
            "DetailType" => line[:detail_type] || line["DetailType"] || "TaxLineDetail",
            "TaxLineDetail" => {
              "TaxRateRef" => map_reference(line[:tax_rate] || line.dig("TaxLineDetail", "TaxRateRef")),
              "PercentBased" => line[:percent_based] || line.dig("TaxLineDetail", "PercentBased"),
              "TaxPercent" => line[:tax_percent] || line.dig("TaxLineDetail", "TaxPercent"),
              "NetAmountTaxable" => line[:net_amount_taxable] || line.dig("TaxLineDetail", "NetAmountTaxable")
            }.compact
          }.compact
        end
      end

      # Map markup info
      def map_markup_info(info)
        return nil unless info

        {
          "PercentBased" => info[:percent_based] || info["PercentBased"],
          "Value" => info[:value] || info["Value"],
          "Percent" => info[:percent] || info["Percent"],
          "PriceLevelRef" => map_reference(info[:price_level] || info["PriceLevelRef"])
        }.compact
      end

      # Map delivery info
      def map_delivery_info(info)
        return nil unless info

        {
          "DeliveryType" => info[:delivery_type] || info["DeliveryType"],
          "DeliveryTime" => info[:delivery_time] || info["DeliveryTime"]
        }.compact
      end

      # Map memo
      def map_memo(memo)
        return nil unless memo

        if memo.is_a?(String)
          { "value" => memo }
        elsif memo.is_a?(Hash)
          memo["value"] ? memo : { "value" => memo[:value] || memo[:message] }
        end
      end

      # Map email
      def map_email(email)
        return nil unless email

        if email.is_a?(String)
          { "Address" => email }
        elsif email.is_a?(Hash)
          email["Address"] ? email : { "Address" => email[:address] || email[:email] }
        end
      end

      # Map custom fields
      def map_custom_fields(fields)
        return nil unless fields
        return fields if fields.is_a?(Array)

        # Convert hash to array format
        fields.map do |key, value|
          {
            "DefinitionId" => key.to_s,
            "StringValue" => value.to_s
          }
        end
      end

      # Helper methods from Customer resource
      def map_reference(ref_data, default_value = nil)
        return nil if ref_data.nil? && default_value.nil?
        return { "value" => default_value } if ref_data.nil?

        if ref_data.is_a?(String) || ref_data.is_a?(Integer)
          { "value" => ref_data.to_s }
        elsif ref_data.is_a?(Hash)
          ref_data["value"] ? ref_data : { "value" => (ref_data[:value] || ref_data[:id]).to_s }
        end
      end

      def map_address(address_data)
        return nil if address_data.nil?
        return address_data if address_data["Line1"] || address_data["City"]

        {
          "Line1" => address_data[:line1] || address_data[:street] || address_data[:address1],
          "Line2" => address_data[:line2] || address_data[:address2],
          "Line3" => address_data[:line3],
          "Line4" => address_data[:line4],
          "Line5" => address_data[:line5],
          "City" => address_data[:city],
          "Country" => address_data[:country],
          "CountrySubDivisionCode" => address_data[:state] || address_data[:country_sub_division_code],
          "PostalCode" => address_data[:postal_code] || address_data[:zip] || address_data[:zip_code],
          "Lat" => address_data[:latitude] || address_data[:lat],
          "Long" => address_data[:longitude] || address_data[:long]
        }.compact
      end

      def escape_sql(value)
        value.to_s.gsub("'", "\\'")
      end

      # Validate that line items exist and have required fields
      def validate_line_items!(attributes)
        lines = attributes["Line"] || attributes[:Line]

        if lines.nil? || (lines.is_a?(Array) && lines.empty?)
          raise FpQbo::ValidationError, "At least one line item is required"
        end

        lines = [lines] unless lines.is_a?(Array)

        lines.each_with_index do |line, index|
          unless line["Amount"] || line[:amount]
            raise FpQbo::ValidationError, "Line item #{index + 1} must have an Amount"
          end

          detail_type = line["DetailType"] || line[:detail_type] || "SalesItemLineDetail"

          next unless detail_type == "SalesItemLineDetail"

          item_ref = line.dig("SalesItemLineDetail", "ItemRef") ||
                     line.dig(:sales_item_detail, :item_ref) ||
                     line[:item_ref] ||
                     line[:item_id]

          unless item_ref
            raise FpQbo::ValidationError, "Line item #{index + 1} must have an ItemRef for SalesItemLineDetail"
          end
        end
      end

      # Calculate due date based on terms
      def calculate_due_date(txn_date, terms_ref)
        return nil unless txn_date && terms_ref

        # This would need to fetch term details and calculate
        # For now, return 30 days from transaction date
        (Date.parse(txn_date) + 30).to_s
      rescue StandardError
        nil
      end

      # Override build_payload to ensure required fields
      def build_payload(attributes)
        # Ensure CustomerRef is present
        raise FpQbo::ValidationError, "CustomerRef is required" unless attributes["CustomerRef"]

        # Ensure Line items are present
        unless attributes["Line"] && attributes["Line"].any?
          raise FpQbo::ValidationError, "At least one Line item is required"
        end

        attributes
      end
    end
  end
end
