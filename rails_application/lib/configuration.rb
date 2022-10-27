require_relative "../../ecommerce/configuration"

class Configuration
  def call(cqrs, event_store)
    enable_res_infra_event_linking(cqrs)

    enable_orders_read_model(event_store)
    enable_products_read_model(event_store)
    enable_public_offer_products_read_model(event_store)
    enable_customers_read_model(cqrs)
    enable_invoices_read_model(cqrs)
    enable_client_orders_read_model(cqrs)
    enable_coupons_read_model(cqrs)
    enable_time_promotions_read_model(cqrs)

    Ecommerce::Configuration.new(
      number_generator: Rails.configuration.number_generator,
      payment_gateway: Rails.configuration.payment_gateway,
      available_vat_rates: [
        Infra::Types::VatRate.new(code: "10", rate: 10),
        Infra::Types::VatRate.new(code: "20", rate: 20)
    ]
    ).call(cqrs)
  end

  private

  def enable_res_infra_event_linking(cqrs)
    [
      RailsEventStore::LinkByEventType.new,
      RailsEventStore::LinkByCorrelationId.new,
      RailsEventStore::LinkByCausationId.new
    ].each { |h| cqrs.subscribe_to_all_events(h) }
  end

  def enable_products_read_model(event_store)
    Products::Configuration.new(event_store).call
  end

  def enable_public_offer_products_read_model(event_store)
    PublicOffer::Configuration.new(event_store).call
  end

  def enable_customers_read_model(cqrs)
    Customers::Configuration.new.call(cqrs)
  end

  def enable_orders_read_model(event_store)
    Orders::Configuration.new.call(event_store)
  end

  def enable_invoices_read_model(cqrs)
    Invoices::Configuration.new.call(cqrs)
  end

  def enable_client_orders_read_model(cqrs)
    ClientOrders::Configuration.new.call(cqrs)
  end

  def enable_coupons_read_model(cqrs)
    Coupons::Configuration.new.call(cqrs)
  end

  def enable_time_promotions_read_model(cqrs)
    TimePromotions::Configuration.new.call(cqrs)
  end
end
