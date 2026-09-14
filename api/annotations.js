module.exports = async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ ok: false, error: "POST only" });
  }
  // Mock only: acknowledge the payload. Do not persist or train.
  return res.status(200).json({ ok: true, stored: false, mock: true });
};
