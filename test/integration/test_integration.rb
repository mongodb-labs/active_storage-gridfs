require "test_helper"  
  
class EngineIntegrationTest < ActionDispatch::IntegrationTest  
  test "engine allows a post to be created" do  
    visit "/posts/new"
    fill_in "Title", with: "My First Post"
    attach_file "File", Rails.root.join("../fixtures/files/sample.txt")
    click_button "Create Post"
    # it should redirect to the post show page
    assert_text "Post was successfully created."
    assert_text "My First Post"
    assert_text "sample.txt"
    # download the file and check its contents
    click_link "sample.txt"
    assert_equal "This is a sample file for testing Active Storage GridFS.\n", page.body
  end  

  test "engine allows a post to be updated" do  
    post = Post.create!(title: "Old Title")
    visit "/posts/#{post.id}/edit"
    fill_in "Title", with: "Updated Title"
    attach_file "File", Rails.root.join("../fixtures/files/sample.txt")
    click_button "Update Post"
    assert_text "Post was successfully updated."
    assert_text "Updated Title"
    assert_text "sample.txt"
    click_link "sample.txt"
    assert_equal "This is a sample file for testing Active Storage GridFS.\n", page.body
  end
end  