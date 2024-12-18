const OpenAI = require("openai");

const client = new OpenAI({});

async function verifyConnection() {
  const chatCompletion = await client.chat.completions.create({
    messages: [{ role: "user", content: "Say this is a test" }],
    model: "gpt-3.5-turbo",
  });

  console.log(chatCompletion);
}

verifyConnection();
transformed;
