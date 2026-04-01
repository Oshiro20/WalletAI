const axios = require('axios');

async function test() {
    try {
        const res = await axios.post('https://api-gastos-6iri.onrender.com/api/parse-voice', {
            systemPrompt: "Hola",
            userMessage: "En qué gasté más?"
        });
        console.log("Success:", res.data);
    } catch (err) {
        console.log("Error status:", err.response?.status);
        console.log("Error data:", err.response?.data);
    }
}

test();
