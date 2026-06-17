<template>
  <div class="article-comments">
    <div class="comments-header">
      <h3 class="comments-title">💬 评论区 ({{ comments.length }})</h3>
      <div class="comments-sort">
        <select v-model="sortBy" @change="sortComments" class="sort-select">
          <option value="newest">最新</option>
          <option value="oldest">最早</option>
          <option value="hot">最热</option>
        </select>
      </div>
    </div>

    <!-- 发表评论 -->
    <div class="comment-form" v-if="isLoggedIn">
      <!-- 使用新的头像组件显示当前用户头像 -->
      <UserAvatar 
        :username="currentUser"
        :avatar-url="currentUserAvatar"
        size="md"
        shape="circle"
        class="form-user-avatar"
      />
      <div class="form-content">
        <textarea
          v-model="newComment"
          placeholder="写下你的想法..."
          class="comment-input"
          rows="3"
          @keydown.ctrl.enter="submitComment"
        ></textarea>
        <div class="form-actions">
          <span class="shortcut-hint">Ctrl + Enter 快速发送</span>
          <button 
            @click="submitComment" 
            :disabled="!newComment.trim()"
            class="submit-btn"
          >
            发表评论
          </button>
        </div>
      </div>
    </div>

    <!-- 未登录提示 -->
    <div class="login-prompt" v-else>
      <p>🔐 登录后即可参与讨论</p>
      <button class="login-btn" @click="$emit('showLogin')">立即登录</button>
    </div>

    <!-- 评论列表 -->
    <div class="comments-list">
      <div v-if="comments.length === 0" class="no-comments">
        <p>🌟 还没有评论，来发表第一条评论吧！</p>
      </div>
      
      <div v-for="comment in sortedComments" :key="comment.id" class="comment-item">
        <div class="comment-avatar">
          <UserAvatar 
            :username="comment.author"
            :avatar-url="comment.authorAvatar"
            size="md"
            shape="circle"
          />
        </div>
        <div class="comment-content">
          <div class="comment-header">
            <span class="comment-author">{{ comment.author }}</span>
            <span class="comment-date">{{ formatDate(comment.createdAt) }}</span>
          </div>
          <div class="comment-text">{{ comment.content }}</div>
          <div class="comment-actions">
            <button 
              class="action-btn like-btn" 
              :class="{ active: comment.isLiked }"
              @click="toggleCommentLike(comment)"
            >
              <span class="icon">👍</span>
              <span>{{ comment.likes || 0 }}</span>
            </button>
            <button class="action-btn reply-btn" @click="showReplyForm(comment)">
              <span class="icon">💬</span>
              <span>回复</span>
            </button>
            <button 
              v-if="comment.author === currentUser"
              class="action-btn delete-btn" 
              @click="deleteComment(comment)"
            >
              <span class="icon">🗑️</span>
              <span>删除</span>
            </button>
          </div>

          <!-- 回复表单 -->
          <div v-if="replyingTo === comment.id && isLoggedIn" class="reply-form">
            <UserAvatar :username="user?.username" :avatar-url="currentUserAvatar" size="sm" shape="circle" />
            <div class="form-content">
              <textarea
                v-model="replyContent"
                :placeholder="`回复 ${comment.author}...`"
                class="comment-input small"
                rows="2"
                @keydown.ctrl.enter="submitReply(comment)"
              ></textarea>
              <div class="form-actions">
                <button @click="cancelReply" class="cancel-btn">取消</button>
                <button 
                  @click="submitReply(comment)" 
                  :disabled="!replyContent.trim()"
                  class="submit-btn small"
                >
                  回复
                </button>
              </div>
            </div>
          </div>

          <!-- 回复列表 -->
          <div v-if="comment.replies && comment.replies.length" class="replies-list">
            <div v-for="reply in comment.replies" :key="reply.id" class="reply-item">
              <div class="comment-avatar small">
                <UserAvatar 
                  :username="reply.author"
                  :avatar-url="reply.authorAvatar"
                  size="sm"
                  shape="circle"
                />
              </div>
              <div class="comment-content">
                <div class="comment-header">
                  <span class="comment-author">{{ reply.author }}</span>
                  <span class="reply-to">回复 {{ comment.author }}</span>
                  <span class="comment-date">{{ formatDate(reply.createdAt) }}</span>
                </div>
                <div class="comment-text">{{ reply.content }}</div>
                <div class="comment-actions">
                  <button 
                    class="action-btn like-btn small" 
                    :class="{ active: reply.isLiked }"
                    @click="toggleReplyLike(reply)"
                  >
                    <span class="icon">👍</span>
                    <span>{{ reply.likes || 0 }}</span>
                  </button>
                  <button 
                    v-if="reply.author === currentUser"
                    class="action-btn delete-btn small" 
                    @click="deleteReply(comment, reply)"
                  >
                    <span class="icon">🗑️</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 加载更多 -->
    <div v-if="hasMore" class="load-more">
      <button @click="loadMoreComments" :disabled="loading" class="load-more-btn">
        {{ loading ? '加载中...' : '加载更多评论' }}
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { commentApi, type Comment, type Reply, type CommentQueryParams } from '@/api/comment'
import toast from '@/utils/toast'
import UserAvatar from '@/components/common/UserAvatar.vue'

const props = defineProps<{
  articleId: number
}>()

const emit = defineEmits<{
  showLogin: []
}>()

// 认证状态
const { isLoggedIn, user } = useAuth()

// 状态管理
const comments = ref<Comment[]>([])
const newComment = ref('')
const replyContent = ref('')
const replyingTo = ref<number | null>(null)
const sortBy = ref<'newest' | 'oldest' | 'hot'>('newest')
const loading = ref(false)
const hasMore = ref(true)
const pageSize = ref(20)

const currentUser = computed(() => user.value?.username || '匿名用户')
const currentUserAvatar = computed(() => user.value?.avatarUrl || '')

// 模拟评论数据 - 待后端评论API实现后替换
onMounted(() => {
  loadComments()
})

const loadComments = async () => {
  loading.value = true
  try {
    const params: CommentQueryParams = {
      page: 0,
      size: pageSize.value,
      sort: sortBy.value
    }
    
    const response = await commentApi.getComments(props.articleId, params)
    // 为评论数据添加头像信息（临时测试用）
    comments.value = response.content.map(comment => ({
      ...comment,
      userAvatar: comment.authorAvatar || '' // 如果没有头像URL，使用空字符串，这样会显示默认头像
    }))
    hasMore.value = !response.last
  } catch (error) {
    console.error('加载评论失败:', error)
    toast.show('加载评论失败，请稍后重试', '错误', { type: 'error' })
    // 如果加载失败，显示空评论列表
    comments.value = []
    hasMore.value = false
  } finally {
    loading.value = false
  }
}

const sortedComments = computed(() => {
  const sorted = [...comments.value]
  switch (sortBy.value) {
    case 'newest':
      return sorted.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    case 'oldest':
      return sorted.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime())
    case 'hot':
      return sorted.sort((a, b) => (b.likes || 0) - (a.likes || 0))
    default:
      return sorted
  }
})

const formatDate = (dateString: string) => {
  const date = new Date(dateString)
  const now = new Date()
  const diff = now.getTime() - date.getTime()
  
  const minutes = Math.floor(diff / (1000 * 60))
  const hours = Math.floor(diff / (1000 * 60 * 60))
  const days = Math.floor(diff / (1000 * 60 * 60 * 24))
  
  if (minutes < 60) {
    return `${minutes}分钟前`
  } else if (hours < 24) {
    return `${hours}小时前`
  } else if (days < 7) {
    return `${days}天前`
  } else {
    return date.toLocaleDateString('zh-CN')
  }
}

const submitComment = async () => {
  if (!newComment.value.trim()) return
  if (!isLoggedIn.value) {
    emit('showLogin')
    return
  }
  
  try {
    const request = {
      articleId: props.articleId,
      content: newComment.value
    }
    const comment = await commentApi.createComment(request)
    comment.authorAvatar = user.value?.avatarUrl || ''
    comments.value.unshift(comment)
    newComment.value = ''
    toast.show('评论发表成功', '成功', { type: 'success' })
  } catch (error) {
    console.error('发表评论失败:', error)
    toast.show('发表评论失败，请稍后重试', '错误', { type: 'error' })
  }
}

const showReplyForm = (comment: Comment) => {
  replyingTo.value = comment.id
  replyContent.value = ''
}

const cancelReply = () => {
  replyingTo.value = null
  replyContent.value = ''
}

const submitReply = async (comment: Comment) => {
  if (!replyContent.value.trim()) return
  if (!isLoggedIn.value) {
    emit('showLogin')
    return
  }
  
  try {
    const reply = await commentApi.createReply(comment.id, replyContent.value)
    reply.authorAvatar = user.value?.avatarUrl || ''
    if (!comment.replies) {
      comment.replies = []
    }
    comment.replies.push(reply)
    cancelReply()
    toast.show('回复发表成功', '成功', { type: 'success' })
  } catch (error) {
    console.error('发表回复失败:', error)
    toast.show('发表回复失败，请稍后重试', '错误', { type: 'error' })
  }
}

const toggleCommentLike = async (comment: Comment) => {
  if (!isLoggedIn.value) {
    emit('showLogin')
    return
  }
  
  try {
    const result = await commentApi.toggleCommentLike(comment.id)
    comment.isLiked = result.liked
    comment.likes = result.likeCount
  } catch (error) {
    console.error('点赞失败:', error)
    toast.show('操作失败，请稍后重试', '错误', { type: 'error' })
  }
}

const toggleReplyLike = async (reply: Reply) => {
  if (!isLoggedIn.value) {
    emit('showLogin')
    return
  }
  
  try {
    const result = await commentApi.toggleCommentLike(reply.id)
    reply.isLiked = result.liked
    reply.likes = result.likeCount
  } catch (error) {
    console.error('点赞失败:', error)
    toast.show('操作失败，请稍后重试', '错误', { type: 'error' })
  }
}

const deleteComment = async (comment: Comment) => {
  if (!confirm('确定要删除这条评论吗？')) return
  
  try {
    await commentApi.deleteComment(comment.id)
    const index = comments.value.findIndex(c => c.id === comment.id)
    if (index > -1) {
      comments.value.splice(index, 1)
    }
    toast.show('评论已删除', '成功', { type: 'success' })
  } catch (error) {
    console.error('删除评论失败:', error)
    toast.show('删除失败，请稍后重试', '错误', { type: 'error' })
  }
}

const deleteReply = async (comment: Comment, reply: Reply) => {
  if (!confirm('确定要删除这条回复吗？')) return
  
  try {
    await commentApi.deleteReply(reply.id)
    const index = comment.replies?.findIndex(r => r.id === reply.id) || -1
    if (index > -1) {
      comment.replies?.splice(index, 1)
    }
    toast.show('回复已删除', '成功', { type: 'success' })
  } catch (error) {
    console.error('删除回复失败:', error)
    toast.show('删除失败，请稍后重试', '错误', { type: 'error' })
  }
}

const sortComments = () => {
  // 排序逻辑已在计算属性中处理
}

const loadMoreComments = async () => {
  loading.value = true
  
  try {
    const currentPage = Math.ceil(comments.value.length / pageSize.value)
    const params: CommentQueryParams = {
      page: currentPage,
      size: pageSize.value,
      sort: sortBy.value
    }
    
    const response = await commentApi.getComments(props.articleId, params)
    comments.value.push(...response.content)
    hasMore.value = !response.last
  } catch (error) {
    console.error('加载更多评论失败:', error)
    toast.show('加载失败，请稍后重试', '错误', { type: 'error' })
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.article-comments {
  width: 100%;
  max-width: 1000px;
  margin: 32px auto 0;
  padding: 32px 24px;
  background: white;
  border-radius: 16px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.06);
  border: 1px solid rgba(226, 232, 240, 0.8);
}

.comments-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  padding-bottom: 16px;
  border-bottom: 2px solid #f7fafc;
}

.comments-title {
  font-size: 1.4rem;
  color: #1a202c;
  font-weight: 600;
  margin: 0;
}

.comments-sort {
  display: flex;
  align-items: center;
  gap: 8px;
}

.sort-select {
  padding: 8px 12px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  background: white;
  color: #4a5568;
  font-size: 0.9rem;
  cursor: pointer;
  transition: border-color 0.2s ease;
}

.sort-select:hover {
  border-color: #667eea;
}

.comment-form, .reply-form {
  display: flex;
  gap: 12px;
  margin-bottom: 24px;
  padding: 20px;
  background: #f8fafc;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
}

.user-avatar {
  width: 40px;
  height: 40px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.2rem;
  font-weight: 600;
  flex-shrink: 0;
}

.user-avatar.small {
  width: 32px;
  height: 32px;
  font-size: 1rem;
}

.form-content {
  flex: 1;
}

.comment-input {
  width: 100%;
  padding: 12px 16px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 0.95rem;
  line-height: 1.5;
  resize: vertical;
  transition: border-color 0.2s ease;
  font-family: inherit;
}

.comment-input:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.comment-input.small {
  font-size: 0.9rem;
  padding: 10px 14px;
}

.form-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 12px;
}

.shortcut-hint {
  color: #a0aec0;
  font-size: 0.8rem;
}

.submit-btn {
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 20px;
  font-size: 0.9rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.3s ease;
}

.submit-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
}

.submit-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.submit-btn.small {
  padding: 8px 16px;
  font-size: 0.85rem;
}

.cancel-btn {
  background: white;
  color: #718096;
  border: 1px solid #e2e8f0;
  padding: 8px 16px;
  border-radius: 20px;
  font-size: 0.85rem;
  cursor: pointer;
  transition: all 0.2s ease;
}

.cancel-btn:hover {
  border-color: #cbd5e0;
  color: #4a5568;
}

.login-prompt {
  text-align: center;
  padding: 32px 20px;
  background: #f8fafc;
  border-radius: 12px;
  margin-bottom: 24px;
}

.login-prompt p {
  color: #718096;
  margin-bottom: 16px;
  font-size: 1rem;
}

.login-btn {
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
  border: none;
  padding: 12px 24px;
  border-radius: 25px;
  font-size: 0.95rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.3s ease;
}

.login-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
}

.no-comments {
  text-align: center;
  padding: 40px 20px;
  color: #a0aec0;
}

.comments-list {
  margin-bottom: 24px;
}

.comment-item {
  display: flex;
  gap: 12px;
  margin-bottom: 24px;
  padding-bottom: 24px;
  border-bottom: 1px solid #f7fafc;
}

.comment-item:last-child {
  border-bottom: none;
  padding-bottom: 0;
  margin-bottom: 0;
}

.comment-avatar {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.comment-avatar.small {
  width: 32px;
  height: 32px;
}

.comment-content {
  flex: 1;
}

.comment-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 8px;
}

.comment-author {
  font-weight: 600;
  color: #1a202c;
  font-size: 0.95rem;
}

.reply-to {
  color: #667eea;
  font-size: 0.85rem;
}

.comment-date {
  color: #a0aec0;
  font-size: 0.85rem;
}

.comment-text {
  color: #4a5568;
  line-height: 1.6;
  margin-bottom: 12px;
  font-size: 0.95rem;
}

.comment-actions {
  display: flex;
  gap: 16px;
  align-items: center;
}

.action-btn {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 6px 12px;
  border: 1px solid #e2e8f0;
  background: white;
  border-radius: 16px;
  font-size: 0.8rem;
  cursor: pointer;
  transition: all 0.2s ease;
  color: #718096;
}

.action-btn.small {
  padding: 4px 8px;
  font-size: 0.75rem;
}

.action-btn:hover {
  background: #f8fafc;
}

.action-btn.active {
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
  border-color: #667eea;
}

.like-btn:hover:not(.active) {
  border-color: #f6ad55;
  color: #f6ad55;
}

.reply-btn:hover {
  border-color: #4299e1;
  color: #4299e1;
}

.delete-btn:hover {
  border-color: #f56565;
  color: #f56565;
}

.replies-list {
  margin-top: 16px;
  padding-left: 16px;
  border-left: 2px solid #f7fafc;
}

.reply-item {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
  padding-bottom: 16px;
  border-bottom: 1px solid #f7fafc;
}

.reply-item:last-child {
  border-bottom: none;
  padding-bottom: 0;
  margin-bottom: 0;
}

.reply-form {
  margin-top: 16px;
  padding: 16px;
  background: white;
}

.load-more {
  text-align: center;
  padding-top: 24px;
  border-top: 1px solid #f7fafc;
}

.load-more-btn {
  background: white;
  color: #667eea;
  border: 2px solid #667eea;
  padding: 12px 24px;
  border-radius: 25px;
  font-size: 0.9rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.3s ease;
}

.load-more-btn:hover:not(:disabled) {
  background: #667eea;
  color: white;
  transform: translateY(-2px);
}

.load-more-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* 响应式设计 */
@media (min-width: 1400px) {
  .article-comments {
    max-width: 1200px;
    padding: 40px 32px;
  }
}

@media (max-width: 768px) {
  .article-comments {
    padding: 24px 16px;
    margin: 24px 16px 0;
  }
  
  .comments-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 12px;
  }
  
  .comment-form, .reply-form {
    padding: 16px;
  }
  
  .comment-actions {
    flex-wrap: wrap;
    gap: 8px;
  }
  
  .action-btn {
    font-size: 0.75rem;
    padding: 5px 10px;
  }
}

@media (max-width: 480px) {
  .comment-item {
    gap: 8px;
  }
  
  .user-avatar, .comment-avatar {
    width: 32px;
    height: 32px;
    font-size: 0.9rem;
  }
  
  .comment-input {
    font-size: 0.9rem;
  }
}
</style>
