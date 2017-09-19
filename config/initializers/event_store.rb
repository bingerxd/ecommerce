Rails.application.config.event_store.tap do |es|
  es.subscribe(Denormalizers::OrderSubmitted.new, [Events::OrderSubmitted])
  es.subscribe(Denormalizers::OrderExpired.new, [Events::OrderExpired])
  es.subscribe(Denormalizers::ItemAddedToBasket.new, [Events::ItemAddedToBasket])
  es.subscribe(Denormalizers::ItemRemovedFromBasket.new, [Events::ItemRemovedFromBasket])
end
