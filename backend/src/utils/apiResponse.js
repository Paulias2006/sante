function ok(res, data, status = 200) {
  return res.status(status).json(data);
}

function fail(res, message, status = 400, details = null) {
  return res.status(status).json({
    message,
    ...(details ? { details } : {}),
  });
}

module.exports = { ok, fail };
