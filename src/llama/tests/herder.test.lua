function TestChatInference(times)
    local testChatPrompt =
    [[{"question":"What are the use cases for a decentralized podcasting app?","context":"Question: What is the UI preview for the upcoming social media platform? Answer: The UI preview shows a functional public prototype for a truly decentralized social media platform.\nQuestion: What is the importance of governance in cryptonetworks? Answer: Governance tokens represent the power to change the rules of the system, and their value increases as the cryptonetwork grows.\nQuestion: Why are content creation and distribution governed by anyone other than creators and end users? Answer: This is a core question driving many underlying issues in society, and the answer lies in the deficiency of the HTTP protocol.\n"}]]

    for i = 1, times do
        Send({
            Target = ao.id,
            Tags = {
                Action = "Inference",
                WorkerType = "Chat",
                Reference = "test" .. tostring(i)
            },
            Data = testChatPrompt,
        })
    end
end

function TestEvaluateInference(times)
    local testEvaluatePrompt =
    [[{"question":"It is 2021-07-10 01:09:09 now. What are the use cases for a decentralized podcasting app?","expected_response":"It is 2021-07-10 03:33:07 now. Announcement of the next permaweb incubator, Open Web Foundry v4, is coming very soon! Anyone up for building a permaweb podcasting app? There are major opportunities in this area.","context":"Question: What is the UI preview for the upcoming social media platform? Answer: The UI preview shows a functional public prototype for a truly decentralized social media platform.\nQuestion: What is the importance of governance in cryptonetworks? Answer: Governance tokens represent the power to change the rules of the system, and their value increases as the cryptonetwork grows.\nQuestion: Why are content creation and distribution governed by anyone other than creators and end users? Answer: This is a core question driving many underlying issues in society, and the answer lies in the deficiency of the HTTP protocol.\n"}]]

    for i = 1, times do
        Send({
            Target = ao.id,
            Tags = {
                Action = "Inference",
                WorkerType = "Evaluate",
                ["X-Reference"] = "test" .. tostring(i)
            },
            Data = testEvaluatePrompt,
        })
    end
end
