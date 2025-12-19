import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

import UserForm from './components/UserForm';
import UserList from './components/UserList';

function App() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);

  // ✅ Backend runs on port 5000
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (!process.env.REACT_APP_API_URL) {
      console.warn('⚠️ REACT_APP_API_URL not set! Using localhost:5000');
    }
  }, []);

  // Fetch all users
  const fetchUsers = async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await axios.get(`${API_URL}/api/users`);
      setUsers(response.data || []);
    } catch (err) {
      console.error('Fetch error:', err);
      
      if (err.code === 'ERR_NETWORK' || err.message === 'Network Error') {
        setError('❌ Cannot connect to server. Is backend running on port 5000?');
      } else if (err.response?.status === 404) {
        setError('❌ API endpoint not found. Check backend routes at port 5000.');
      } else {
        const msg = err.response?.data?.error || err.message || 'Failed to fetch users';
        setError(msg);
      }
      
      setUsers([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  // Add user
  const handleAddUser = async (formData) => {
    setLoading(true);
    
    try {
      await axios.post(`${API_URL}/api/users`, {
        name: `${formData.firstName} ${formData.lastName}`,
        email: formData.email,
        phone: formData.phone || null
      });

      setSuccess("✅ User added successfully!");
      setError(null);
      setTimeout(() => setSuccess(null), 2500);

      fetchUsers();
    } catch (err) {
      console.error('Add user error:', err);
      const msg = err.response?.data?.error || err.message || "Failed to add user.";
      setError(`❌ ${msg}`);
      setSuccess(null);
    } finally {
      setLoading(false);
    }
  };

  // Delete user
  const handleDeleteUser = async (id) => {
    if (!window.confirm("Are you sure you want to delete this user?")) return;

    setLoading(true);
    
    try {
      await axios.delete(`${API_URL}/api/users/${id}`);
      setSuccess("✅ User deleted successfully!");
      setError(null);
      setTimeout(() => setSuccess(null), 2500);

      fetchUsers();
    } catch (err) {
      console.error('Delete error:', err);
      setError("❌ Failed to delete user. Try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="App">
      <div className="container">

        <header className="header">
          <h1>Dhruvi's User Input Application</h1>
          <p>Manage user information easily</p>
          <small style={{ opacity: 0.6 }}>API: {API_URL}</small>
        </header>

        {success && <div className="alert alert-success">{success}</div>}
        {error && <div className="alert alert-error">{error}</div>}

        <div className="content">

          {/* Form */}
          <div className="form-section">
            <h2>Add New User</h2>
            <UserForm onSubmit={handleAddUser} disabled={loading} />
          </div>

          {/* List */}
          <div className="list-section">
            <h2>Users List ({users.length})</h2>

            {loading ? (
              <div className="loading">⏳ Loading users...</div>
            ) : users.length === 0 ? (
              <div className="empty-state">
                📋 No users found. Add one above!
              </div>
            ) : (
              <UserList users={users} onDelete={handleDeleteUser} />
            )}
          </div>

        </div>
      </div>
    </div>
  );
}

export default App;