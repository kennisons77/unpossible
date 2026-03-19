class Concern < ApplicationRecord
  belongs_to :owner, class_name: 'User'
  has_many :documents, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :owner_id }

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :unconfirmed, -> { where(confirmed_at: nil) }

  def confirm!
    update!(confirmed_at: Time.current)
  end
end
