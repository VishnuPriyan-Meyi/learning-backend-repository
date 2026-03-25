// ── Lambda Handler ────────────────────────────────────────────
export const handler = (event) => {
console.log("[event object] - ",event)
  // Health check
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
    body: JSON.stringify({
      status: 'ok',
      message: 'Learning Backend Lambda is running!',  
      timestamp: new Date().toISOString(),
      event: event
    }),
  };
};