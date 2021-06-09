require_relative 'test_helper'

module Payments
  class PaymentTest < ActiveSupport::TestCase
    include TestPlumbing

    cover 'Payments::Payment*'

    def test_authorize_publishes_event
      payment = Payment.new
      gateway = FakeGateway.new
      payment.authorize(transaction_id, order_id, gateway, 20)
      assert_changes(payment.unpublished_events, [
        PaymentAuthorized.new(data: {
          transaction_id: transaction_id,
          order_id: order_id,
        })
      ])
    end

    def test_authorize_contacts_gateway
      payment = Payment.new
      gateway = FakeGateway.new
      payment.authorize(transaction_id, order_id, gateway, 20)
      assert(gateway.authorized_transactions.include?([transaction_id, 20]))
    end

    def test_should_not_allow_for_double_authorization
      assert_raises(Payment::AlreadyAuthorized) do
        authorized_payment.authorize(transaction_id, order_id, nil, 20)
      end
    end

    def test_should_capture_authorized_payment
      payment = authorized_payment
      before = payment.unpublished_events.to_a

      payment.capture
      actual = payment.unpublished_events.to_a - before
      assert_changes(actual, [
        PaymentCaptured.new(data: {
          transaction_id: transaction_id,
          order_id: order_id,
        })
      ])
    end

    def test_must_not_capture_not_authorized_payment
      assert_raises(Payment::NotAuthorized) do
        Payment.new.capture
      end
    end

    def test_should_not_allow_for_double_capture
      assert_raises(Payment::AlreadyCaptured) do
        captured_payment.capture
      end
    end

    def test_authorization_could_be_released
      payment = authorized_payment
      before = payment.unpublished_events.to_a

      payment.release
      actual = payment.unpublished_events.to_a - before
      assert_changes(actual, [
        PaymentReleased.new(data: {
          transaction_id: transaction_id,
          order_id: order_id,
        })
      ])
    end

    def test_must_not_release_not_captured_payment
      assert_raises(Payment::AlreadyCaptured) do
        captured_payment.release
      end
    end

    def test_must_not_release_not_authorized_payment
      assert_raises(Payment::NotAuthorized) do
        Payment.new.release
      end
    end

    def test_should_not_allow_for_double_release
      assert_raises(Payment::AlreadyReleased) do
        released_payment.release
      end
    end

    private
    def transaction_id
      @transaction_id ||= SecureRandom.hex(16)
    end

    def order_id
      @order_id ||= SecureRandom.uuid
    end

    def authorized_payment
      Payment.new.tap do |payment|
        payment.apply(
          PaymentAuthorized.new(data: {
            transaction_id: transaction_id,
            order_id: order_id,
          })
        )
      end
    end

    def captured_payment
      authorized_payment.tap do |payment|
        payment.apply(
          PaymentCaptured.new(data: {
            transaction_id: transaction_id,
            order_id: order_id,
          })
        )
      end
    end

    def released_payment
      captured_payment.tap do |payment|
        payment.apply(
          PaymentReleased.new(data: {
            transaction_id: transaction_id,
            order_id: order_id,
          })
        )
      end
    end
  end
end
