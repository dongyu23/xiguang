CREATE TABLE IF NOT EXISTS pending_payment_refunds (
  provider payment_provider NOT NULL,
  transaction_id VARCHAR(256) NOT NULL,
  refunded_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(provider, transaction_id)
);
