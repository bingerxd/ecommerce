
require "test_helper"

class HappyHoursTest < InMemoryRESIntegrationTestCase
  def test_happy_hours_list
    product_id = SecureRandom.uuid
    run_command(
      ProductCatalog::RegisterProduct.new(
        product_id: product_id,
        name: "Domain Driven-Design"
      )
    )

    run_command(
      Pricing::CreateHappyHour.new(
        details: {
          name: "Night Owls",
          code: "owls",
          discount: "25",
          start_hour: "20",
          end_hour: "1",
          product_ids: [product_id]
        }
      )
    )

    get "/happy_hours"
    assert_response :success
    assert_select("td", "Night Owls")
    assert_select("td", "owls")
    assert_select("td", "25")
    assert_select("td", "20")
    assert_select("td", "1")
    assert_select("td", "Domain Driven-Design")
  end

  def test_create_happy_hour
    product_id = SecureRandom.uuid
    run_command(
      ProductCatalog::RegisterProduct.new(
        product_id: product_id,
        name: "How to kill a mockingbird"
      )
    )

    post "/happy_hours", params: {
      name: "Morning Stars",
      code: "stars",
      discount: "15",
      start_hour: "4",
      end_hour: "8",
      product_ids: [product_id]
    }
    follow_redirect!
    assert_response :success
    assert_select("p", "Happy hour was successfully created")
    assert_select("td", "Morning Stars")
    assert_select("td", "stars")
    assert_select("td", "15")
    assert_select("td", "4")
    assert_select("td", "8")
    assert_select("td", "How to kill a mockingbird")
  end
end