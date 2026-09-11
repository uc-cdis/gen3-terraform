mock_provider "aws" {}

variables {
  name_prefix               = "test-lt-"
  instance_type             = "t3.medium"
  image_id                  = "ami-12345678"
  iam_instance_profile_name = "test-profile"
  security_group_ids        = ["sg-aabbccdd", "sg-11223344"]
  user_data                 = "#!/bin/bash\necho hello"
}

run "tag_specifications_present_when_name_tag_set" {
  command = plan

  variables {
    name_tag = "my-instance"
  }

  assert {
    condition     = length(aws_launch_template.this.tag_specifications) == 1
    error_message = "tag_specifications must be created when name_tag is non-empty"
  }

  assert {
    condition     = aws_launch_template.this.tag_specifications[0].tags["Name"] == "my-instance"
    error_message = "Name tag must match name_tag variable"
  }
}

run "tag_specifications_suppressed_when_name_tag_empty" {
  command = plan

  variables {
    name_tag = ""
  }

  assert {
    condition     = length(aws_launch_template.this.tag_specifications) == 0
    error_message = "tag_specifications must be omitted when name_tag is empty"
  }
}

run "key_name_nulled_when_empty_string" {
  command = plan

  variables {
    key_name = ""
  }

  assert {
    condition     = aws_launch_template.this.key_name == null
    error_message = "key_name must be null when an empty string is passed"
  }
}

run "user_data_is_base64_encoded" {
  command = plan

  assert {
    condition     = can(base64decode(aws_launch_template.this.user_data))
    error_message = "user_data must be valid base64"
  }

  assert {
    condition     = base64decode(aws_launch_template.this.user_data) == "#!/bin/bash\necho hello"
    error_message = "user_data base64 must decode to the raw string passed in"
  }
}

run "extra_tags_merged_with_name_tag" {
  command = plan

  variables {
    name_tag   = "my-instance"
    extra_tags = { Environment = "test" }
  }

  assert {
    condition     = aws_launch_template.this.tag_specifications[0].tags["Environment"] == "test"
    error_message = "extra_tags must be merged into tag_specifications"
  }
}
