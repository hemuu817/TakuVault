def csrf_token
  ActionController::Base.helpers.form_authenticity_token
end

def sign_in(user)
  post sign_in_path, params: { user: { email: user.email, password: user.password } }, headers: { 'X-CSRF-Token' => csrf_token }
end
