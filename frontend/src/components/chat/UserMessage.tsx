import { MessageBubble } from "./MessageBubble";

interface UserMessageProps {
  content: string;
}

export function UserMessage({ content }: UserMessageProps) {
  return (
    <div className="flex justify-end">
      <div className="max-w-[82%] md:max-w-[70%]">
        <MessageBubble role="user">
          <p className="whitespace-pre-wrap">{content}</p>
        </MessageBubble>
      </div>
    </div>
  );
}
