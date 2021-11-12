module Orders
  class Order < ApplicationRecord
    self.table_name = "orders"

    has_many :order_lines,
             -> { order(id: :asc) },
             class_name: "Orders::OrderLine",
             foreign_key: :order_uid,
             primary_key: :uid
  end

  class OrderLine < ApplicationRecord
    self.table_name = "order_lines"

    def value
      price * quantity
    end
  end

  class Configuration
    def initialize(product_repository, customer_repository)
      @product_repository = product_repository
      @customer_repository = customer_repository
    end

    def call(cqrs)
      @cqrs = cqrs

      subscribe_and_link_to_stream(
        ->(event) { mark_as_submitted(event) },
        [Ordering::OrderSubmitted]
      )
      subscribe_and_link_to_stream(
        ->(event) { change_order_state(event, "Expired") },
        [Ordering::OrderExpired]
      )
      subscribe_and_link_to_stream(
        ->(event) { change_order_state(event, "Paid") },
        [Ordering::OrderPaid]
      )
      subscribe_and_link_to_stream(
        ->(event) { change_order_state(event, "Cancelled") },
        [Ordering::OrderCancelled]
      )
      subscribe_and_link_to_stream(
        ->(event) { add_item_to_order(event) },
        [Ordering::ItemAddedToBasket]
      )
      subscribe_and_link_to_stream(
        ->(event) { remove_item_from_order(event) },
        [Ordering::ItemRemovedFromBasket]
      )
      subscribe_and_link_to_stream(
        ->(event) { update_discount(event) },
        [Pricing::PercentageDiscountSet]
      )
      subscribe_and_link_to_stream(
        ->(event) { update_totals(event) },
        [Pricing::OrderTotalValueCalculated]
      )

      subscribe(
        -> (event) { create_product(event) },
        [ProductCatalog::ProductRegistered]
      )

      subscribe(
        -> (event) { change_product_price(event) },
        [Pricing::PriceSet]
      )
    end

    private

    def subscribe_and_link_to_stream(handler, events)
      link_and_handle = ->(event) do
        link_to_stream(event)
        handler.call(event)
      end
      @cqrs.subscribe(link_and_handle, events)
    end

    def subscribe(handler, events)
      @cqrs.subscribe(handler, events)
    end

    def mark_as_submitted(event)
      order = Order.find_or_create_by(uid: event.data.fetch(:order_id))
      order.number = event.data.fetch(:order_number)
      order.customer = @customer_repository.find(event.data.fetch(:customer_id)).name
      order.state = "Submitted"
      order.save!
    end

    def link_to_stream(event)
      @cqrs.link_event_to_stream(event, "Orders$#{event.data.fetch(:order_id)}")
    end

    def add_item_to_order(event)
      order_id = event.data.fetch(:order_id)
      create_draft_order(order_id)
      item =
        find(order_id, event.data.fetch(:product_id)) ||
          create(order_id, event.data.fetch(:product_id))
      item.quantity += 1
      item.save!
    end

    def create_draft_order(uid)
      return if Order.where(uid: uid).exists?
      Order.create!(uid: uid, state: "Draft")
    end

    def find(order_uid, product_id)
      Order
        .find_by_uid(order_uid)
        .order_lines
        .where(product_id: product_id)
        .first
    end

    def create(order_uid, product_id)
      product = @product_repository.find(product_id)
      Order
        .find_by(uid: order_uid)
        .order_lines
        .create(
          product_id: product_id,
          product_name: product.name,
          price: product.price,
          quantity: 0
        )
    end

    def remove_item_from_order(event)
      item = find(event.data.fetch(:order_id), event.data.fetch(:product_id))
      item.quantity -= 1
      item.quantity > 0 ? item.save! : item.destroy!
    end

    def update_discount(event)
      with_order(event) do |order|
        order.percentage_discount = event.data.fetch(:amount)
      end
    end

    def update_totals(event)
      with_order(event) do |order|
        order.discounted_value = event.data.fetch(:discounted_amount)
      end
    end

    def change_order_state(event, new_state)
      with_order(event) { |order| order.state = new_state }
    end

    def with_order(event)
      Order
        .find_by_uid(event.data.fetch(:order_id))
        .tap do |order|
          yield(order)
          order.save!
        end
    end

    def create_product(event)
    end

    def change_product_price(event)
    end
  end
end
